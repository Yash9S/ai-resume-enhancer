# spec/controllers/resumes_controller_data_flow_spec.rb
require 'rails_helper'

RSpec.describe ResumesController, type: :controller do
  let(:user) { create(:user) }
  let(:tenant) { create(:tenant, :active) }

  before do
    Apartment::Tenant.switch(tenant.subdomain) do
      sign_in user
    end
  end

  describe 'data flow through controller actions' do
    describe 'POST #create' do
      let(:valid_attributes) do
        {
          title: 'Software Engineer Resume',
          file: fixture_file_upload('sample_resume.pdf', 'application/pdf')
        }
      end

      let(:invalid_attributes) do
        {
          title: '',
          file: fixture_file_upload('invalid_file.txt', 'text/plain')
        }
      end

      context 'with valid data' do
        it 'creates resume with correct data flow' do
          Apartment::Tenant.switch(tenant.subdomain) do
            expect {
              post :create, params: { resume: valid_attributes }
            }.to change(Resume, :count).by(1)

            resume = Resume.last
            
            # Validate data persistence
            expect(resume.title).to eq('Software Engineer Resume')
            expect(resume.user).to eq(user)
            expect(resume.status).to eq('uploaded')
            expect(resume.processing_status).to eq('pending')
            expect(resume.file).to be_attached
            expect(resume.file.filename.to_s).to eq('sample_resume.pdf')
            expect(resume.file.content_type).to eq('application/pdf')
            
            # Validate response
            expect(response).to redirect_to(resume)
            expect(flash[:notice]).to eq('Resume was successfully uploaded.')
          end
        end

        it 'handles file upload data correctly' do
          Apartment::Tenant.switch(tenant.subdomain) do
            post :create, params: { resume: valid_attributes }
            
            resume = Resume.last
            
            # Validate file data integrity
            expect(resume.file_size).to be > 0
            expect(resume.file.blob.byte_size).to be > 0
            expect(resume.file.blob.checksum).to be_present
            
            # Should be able to read file content
            file_content = resume.file.download
            expect(file_content).to be_present
            expect(file_content.bytesize).to eq(resume.file_size)
          end
        end

        it 'sets correct initial processing state' do
          Apartment::Tenant.switch(tenant.subdomain) do
            post :create, params: { resume: valid_attributes }
            
            resume = Resume.last
            
            expect(resume.processing_status).to eq('pending')
            expect(resume.processing_started_at).to be_nil
            expect(resume.processing_completed_at).to be_nil
            expect(resume.processing_error).to be_nil
            expect(resume.extraction_confidence).to be_nil
            expect(resume.has_ai_data?).to be false
          end
        end
      end

      context 'with invalid data' do
        it 'handles validation errors correctly' do
          Apartment::Tenant.switch(tenant.subdomain) do
            expect {
              post :create, params: { resume: invalid_attributes }
            }.not_to change(Resume, :count)

            expect(response).to render_template(:new)
            expect(assigns(:resume).errors).to be_present
            expect(assigns(:resume).errors[:title]).to include("can't be blank")
            expect(assigns(:resume).errors[:file]).to include('must be a PDF or DOCX file')
          end
        end

        it 'preserves form data on validation failure' do
          Apartment::Tenant.switch(tenant.subdomain) do
            post :create, params: { resume: invalid_attributes }
            
            resume = assigns(:resume)
            expect(resume.title).to eq('')
            expect(response.body).to include('must be a PDF or DOCX file')
          end
        end
      end
    end

    describe 'POST #process' do
      let(:resume) { create(:resume, :with_file, user: user) }

      before do
        # Mock AI service for processing tests
        stub_request(:get, "http://ai-service:8000/health")
          .to_return(status: 200, body: { status: "healthy" }.to_json)

        stub_request(:post, "http://ai-service:8000/extract")
          .to_return(
            status: 200,
            body: {
              "ai_response" => "```json\n{\"name\": \"Test User\", \"email\": \"test@example.com\"}\n```",
              "confidence" => 0.85
            }.to_json
          )
      end

      it 'initiates AI processing with correct data flow' do
        Apartment::Tenant.switch(tenant.subdomain) do
          expect {
            post :process, params: { id: resume.id }
          }.to have_enqueued_job(ResumeProcessingJob)
            .with(resume.id, nil, 'ollama')
            .on_queue('high')

          resume.reload
          expect(resume.processing_status).to eq('queued')
          expect(resume.processing_error).to be_nil
          expect(response).to redirect_to(resume)
          expect(flash[:notice]).to eq('Resume processing started.')
        end
      end

      it 'handles job description parameter correctly' do
        Apartment::Tenant.switch(tenant.subdomain) do
          job_description = create(:job_description, user: user)

          expect {
            post :process, params: { id: resume.id, job_description_id: job_description.id }
          }.to have_enqueued_job(ResumeProcessingJob)
            .with(resume.id, job_description.id, 'ollama')

          expect(response).to redirect_to(resume)
        end
      end

      it 'handles provider parameter correctly' do
        Apartment::Tenant.switch(tenant.subdomain) do
          expect {
            post :process, params: { id: resume.id, provider: 'basic' }
          }.to have_enqueued_job(ResumeProcessingJob)
            .with(resume.id, nil, 'basic')

          expect(response).to redirect_to(resume)
        end
      end

      it 'resets previous processing state' do
        Apartment::Tenant.switch(tenant.subdomain) do
          # Set failed state
          resume.update!(
            processing_status: 'failed',
            processing_error: 'Previous error',
            processing_started_at: 1.hour.ago
          )

          post :process, params: { id: resume.id }

          resume.reload
          expect(resume.processing_status).to eq('queued')
          expect(resume.processing_error).to be_nil
          expect(resume.processing_started_at).to be_nil
        end
      end
    end

    describe 'POST #reprocess' do
      let(:resume) { create(:resume, :with_ai_data, user: user) }

      it 'reinitializes processing for existing resume' do
        Apartment::Tenant.switch(tenant.subdomain) do
          # Ensure resume has existing data
          expect(resume.has_ai_data?).to be true
          expect(resume.processing_status).to eq('completed')

          expect {
            post :reprocess, params: { id: resume.id }
          }.to have_enqueued_job(ResumeProcessingJob)

          resume.reload
          expect(resume.processing_status).to eq('queued')
          expect(resume.processing_error).to be_nil
          expect(response).to redirect_to(resume)
          expect(flash[:notice]).to eq('Resume reprocessing started.')
        end
      end

      it 'handles reprocessing with different provider' do
        Apartment::Tenant.switch(tenant.subdomain) do
          expect {
            post :reprocess, params: { id: resume.id, provider: 'basic' }
          }.to have_enqueued_job(ResumeProcessingJob)
            .with(resume.id, nil, 'basic')
        end
      end
    end

    describe 'GET #show' do
      context 'with AI processed resume' do
        let(:resume) do
          create(:resume, :with_ai_data, user: user,
            extracted_name: 'John Doe',
            extracted_email: 'john@example.com',
            extracted_phone: '+1-555-123-4567',
            extracted_skills: '["Ruby", "JavaScript", "Python"]',
            extracted_experience: '[{"company": "TechCorp", "position": "Developer"}]'
          )
        end

        it 'displays processed data correctly' do
          Apartment::Tenant.switch(tenant.subdomain) do
            get :show, params: { id: resume.id }

            expect(response).to have_http_status(:success)
            expect(assigns(:resume)).to eq(resume)
            
            # Validate AI data is available to view
            ai_data = assigns(:resume).ai_extracted_data
            expect(ai_data[:name]).to eq('John Doe')
            expect(ai_data[:email]).to eq('john@example.com')
            expect(ai_data[:skills]).to include('Ruby', 'JavaScript', 'Python')
            
            # Validate view renders the data
            expect(response.body).to include('John Doe')
            expect(response.body).to include('john@example.com')
            expect(response.body).to include('TechCorp')
          end
        end

        it 'handles JSON parsing errors gracefully' do
          Apartment::Tenant.switch(tenant.subdomain) do
            # Corrupt the JSON data
            resume.update!(extracted_skills: 'invalid json')

            get :show, params: { id: resume.id }

            expect(response).to have_http_status(:success)
            
            # Should handle gracefully without crashing
            ai_data = assigns(:resume).ai_extracted_data
            expect(ai_data[:skills]).to eq([])
          end
        end
      end

      context 'with processing resume' do
        let(:resume) do
          create(:resume, :with_file, user: user,
            processing_status: 'processing',
            processing_started_at: 30.seconds.ago
          )
        end

        it 'shows processing status correctly' do
          Apartment::Tenant.switch(tenant.subdomain) do
            get :show, params: { id: resume.id }

            expect(response).to have_http_status(:success)
            expect(assigns(:resume).processing_status).to eq('processing')
            expect(response.body).to include('Processing')
          end
        end
      end

      context 'with failed processing' do
        let(:resume) do
          create(:resume, :with_file, user: user,
            processing_status: 'failed',
            processing_error: 'AI service timeout'
          )
        end

        it 'displays error information' do
          Apartment::Tenant.switch(tenant.subdomain) do
            get :show, params: { id: resume.id }

            expect(response).to have_http_status(:success)
            expect(assigns(:resume).processing_error).to eq('AI service timeout')
            expect(response.body).to include('AI service timeout')
          end
        end
      end
    end

    describe 'PATCH #update' do
      let(:resume) { create(:resume, :with_ai_data, user: user) }

      let(:update_params) do
        {
          extracted_name: 'Updated Name',
          extracted_email: 'updated@example.com',
          extracted_phone: '+1-555-999-8888'
        }
      end

      it 'updates AI extracted data correctly' do
        Apartment::Tenant.switch(tenant.subdomain) do
          patch :update, params: {
            id: resume.id,
            resume: update_params
          }

          resume.reload
          
          expect(resume.extracted_name).to eq('Updated Name')
          expect(resume.extracted_email).to eq('updated@example.com')
          expect(resume.extracted_phone).to eq('+1-555-999-8888')
          
          expect(response).to redirect_to(resume)
          expect(flash[:notice]).to eq('Resume was successfully updated.')
        end
      end

      it 'validates updated data format' do
        Apartment::Tenant.switch(tenant.subdomain) do
          # Test with invalid JSON for skills
          patch :update, params: {
            id: resume.id,
            resume: { extracted_skills: 'invalid json format' }
          }

          resume.reload
          
          # Should still save even if JSON is invalid (validation handled by model)
          expect(resume.extracted_skills).to eq('invalid json format')
          expect(resume.ai_extracted_data[:skills]).to eq([]) # Graceful handling
        end
      end

      it 'handles concurrent updates correctly' do
        Apartment::Tenant.switch(tenant.subdomain) do
          original_updated_at = resume.updated_at

          # Simulate delay
          sleep(0.1)

          patch :update, params: {
            id: resume.id,
            resume: update_params
          }

          resume.reload
          expect(resume.updated_at).to be > original_updated_at
          expect(resume.extracted_name).to eq('Updated Name')
        end
      end
    end

    describe 'data consistency across actions' do
      let(:resume) { create(:resume, :with_file, user: user) }

      it 'maintains data integrity through processing cycle' do
        Apartment::Tenant.switch(tenant.subdomain) do
          # Initial state
          get :show, params: { id: resume.id }
          expect(assigns(:resume).has_ai_data?).to be false

          # Start processing
          post :process, params: { id: resume.id }
          resume.reload
          expect(resume.processing_status).to eq('queued')

          # Simulate processing completion
          perform_enqueued_jobs do
            ResumeProcessingJob.perform_now(resume.id, nil, 'ollama')
          end

          # Verify processed state
          get :show, params: { id: resume.id }
          resume.reload
          
          expect(resume.processing_status).to eq('completed')
          expect(resume.has_ai_data?).to be true
          expect(assigns(:resume)).to eq(resume)

          # Update extracted data
          patch :update, params: {
            id: resume.id,
            resume: { extracted_name: 'Manual Update' }
          }

          # Verify update persisted
          get :show, params: { id: resume.id }
          expect(assigns(:resume).extracted_name).to eq('Manual Update')
        end
      end

      it 'handles processing state transitions correctly' do
        Apartment::Tenant.switch(tenant.subdomain) do
          # Upload -> Queued
          post :process, params: { id: resume.id }
          resume.reload
          expect(resume.processing_status).to eq('queued')

          # Queued -> Processing (simulated by job)
          resume.update!(
            processing_status: 'processing',
            processing_started_at: Time.current
          )

          get :show, params: { id: resume.id }
          expect(assigns(:resume).processing_status).to eq('processing')

          # Processing -> Completed
          resume.update!(
            processing_status: 'completed',
            processing_completed_at: Time.current,
            extracted_name: 'Test Name'
          )

          get :show, params: { id: resume.id }
          expect(assigns(:resume).processing_status).to eq('completed')
          expect(assigns(:resume).extracted_name).to eq('Test Name')
        end
      end
    end
  end

  describe 'error handling in data flow' do
    let(:resume) { create(:resume, :with_file, user: user) }

    it 'handles missing resume gracefully' do
      Apartment::Tenant.switch(tenant.subdomain) do
        expect {
          get :show, params: { id: 99999 }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    it 'handles processing errors with proper data state' do
      Apartment::Tenant.switch(tenant.subdomain) do
        # Simulate failed processing
        resume.update!(
          processing_status: 'failed',
          processing_error: 'Network timeout',
          processing_started_at: 1.minute.ago
        )

        get :show, params: { id: resume.id }
        
        expect(response).to have_http_status(:success)
        expect(assigns(:resume).processing_status).to eq('failed')
        expect(assigns(:resume).processing_error).to eq('Network timeout')
        expect(assigns(:resume).has_ai_data?).to be false
      end
    end

    it 'validates user access to resume data' do
      Apartment::Tenant.switch(tenant.subdomain) do
        other_user = create(:user, email: 'other@example.com')
        other_resume = create(:resume, :with_file, user: other_user)

        expect {
          get :show, params: { id: other_resume.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'multitenancy data isolation' do
    let(:other_tenant) { create(:tenant, :active, subdomain: 'othertenant') }
    let(:other_user) { create(:user, email: 'other@tenant.com') }

    it 'isolates resume data by tenant' do
      # Create resume in first tenant
      tenant_resume = nil
      Apartment::Tenant.switch(tenant.subdomain) do
        tenant_resume = create(:resume, :with_file, user: user)
      end

      # Try to access from second tenant
      Apartment::Tenant.switch(other_tenant.subdomain) do
        sign_in other_user
        
        expect {
          get :show, params: { id: tenant_resume.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    it 'maintains data integrity across tenant switches' do
      resume_id = nil
      
      # Create and process in tenant 1
      Apartment::Tenant.switch(tenant.subdomain) do
        resume = create(:resume, :with_file, user: user)
        resume_id = resume.id
        
        post :process, params: { id: resume.id }
        resume.reload
        expect(resume.processing_status).to eq('queued')
      end

      # Switch tenants and back
      Apartment::Tenant.switch(other_tenant.subdomain) do
        # Different tenant context
      end

      # Verify data integrity in original tenant
      Apartment::Tenant.switch(tenant.subdomain) do
        get :show, params: { id: resume_id }
        expect(assigns(:resume).processing_status).to eq('queued')
        expect(assigns(:resume).user).to eq(user)
      end
    end
  end
end
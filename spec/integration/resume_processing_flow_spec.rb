# spec/integration/resume_processing_flow_spec.rb
require 'rails_helper'

RSpec.describe 'Resume Processing Flow', type: :request do
  let(:user) { create(:user) }
  let(:tenant) { create(:tenant, :active) }
  
  before do
    Apartment::Tenant.switch(tenant.subdomain) do
      sign_in user
    end
  end

  describe 'complete data flow from upload to AI processing' do
    let(:mock_ai_response) do
      {
        "name": "John Doe",
        "email": "john@example.com", 
        "phone": "+1-555-123-4567",
        "location": "San Francisco, CA",
        "summary": "Experienced software engineer with 5+ years of experience",
        "skills": ["Ruby", "JavaScript", "Python", "Rails", "React", "PostgreSQL"],
        "experience": [
          {
            "company": "TechCorp Inc",
            "position": "Senior Software Engineer",
            "duration": "2020-Present",
            "description": "Led development of microservices architecture"
          },
          {
            "company": "StartupXYZ",
            "position": "Full Stack Developer", 
            "duration": "2018-2020",
            "description": "Built web applications using Ruby on Rails"
          }
        ],
        "education": [
          {
            "degree": "Bachelor of Science in Computer Science",
            "institution": "University of California",
            "year": "2018"
          }
        ]
      }
    end

    let(:ai_service_response) do
      {
        status: 200,
        body: {
          "ai_response" => "```json\n#{mock_ai_response.to_json}\n```",
          "confidence" => 0.92,
          "processing_time" => 45.5
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      }
    end

    before do
      # Mock AI service health check
      stub_request(:get, "http://ai-service:8000/health")
        .to_return(status: 200, body: { status: "healthy" }.to_json)

      # Mock AI service processing endpoint
      stub_request(:post, "http://ai-service:8000/extract")
        .with(
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json'
          }
        )
        .to_return(ai_service_response)
    end

    context 'successful processing flow' do
      it 'processes complete data pipeline from upload to database storage' do
        Apartment::Tenant.switch(tenant.subdomain) do
          # Step 1: Upload resume file
          file = fixture_file_upload('sample_resume.pdf', 'application/pdf')
          
          post '/resumes', params: {
            resume: {
              title: 'My Resume 2024',
              file: file
            }
          }
          
          expect(response).to redirect_to(assigns(:resume))
          resume = Resume.last
          
          # Validate initial state
          expect(resume).to be_present
          expect(resume.title).to eq('My Resume 2024')
          expect(resume.status).to eq('uploaded')
          expect(resume.processing_status).to eq('pending')
          expect(resume.user).to eq(user)
          expect(resume.file).to be_attached
          expect(resume.has_ai_data?).to be false
          
          # Step 2: Trigger AI processing
          expect {
            post "/resumes/#{resume.id}/process"
          }.to have_enqueued_job(ResumeProcessingJob)
            .with(resume.id, nil, 'ollama')
            .on_queue('high')
          
          resume.reload
          expect(resume.processing_status).to eq('queued')
          
          # Step 3: Execute background job (simulates worker processing)
          perform_enqueued_jobs do
            ResumeProcessingJob.perform_now(resume.id, nil, 'ollama')
          end
          
          # Step 4: Validate HTTP requests were made correctly
          expect(a_request(:get, "http://ai-service:8000/health")).to have_been_made.once
          
          expect(a_request(:post, "http://ai-service:8000/extract")
            .with { |request|
              body = JSON.parse(request.body)
              expect(body).to have_key('file_content')
              expect(body).to have_key('filename')
              expect(body['filename']).to eq('sample_resume.pdf')
              expect(body['processing_options']).to include('timeout' => 120)
              true
            }
          ).to have_been_made.once
          
          # Step 5: Validate database state after processing
          resume.reload
          
          expect(resume.status).to eq('processed')
          expect(resume.processing_status).to eq('completed')
          expect(resume.processing_started_at).to be_present
          expect(resume.processing_completed_at).to be_present
          expect(resume.processing_error).to be_nil
          expect(resume.extraction_confidence).to eq(0.92)
          
          # Step 6: Validate extracted data consistency
          expect(resume.has_ai_data?).to be true
          
          # Contact information validation
          expect(resume.extracted_name).to eq('John Doe')
          expect(resume.extracted_email).to eq('john@example.com')
          expect(resume.extracted_phone).to eq('+1-555-123-4567')
          expect(resume.extracted_location).to eq('San Francisco, CA')
          expect(resume.extracted_summary).to eq('Experienced software engineer with 5+ years of experience')
          
          # Skills validation (JSON array)
          parsed_skills = JSON.parse(resume.extracted_skills)
          expect(parsed_skills).to be_an(Array)
          expect(parsed_skills.length).to eq(6)
          expect(parsed_skills).to include('Ruby', 'JavaScript', 'Python', 'Rails', 'React', 'PostgreSQL')
          
          # Experience validation (JSON array of objects)
          parsed_experience = JSON.parse(resume.extracted_experience)
          expect(parsed_experience).to be_an(Array)
          expect(parsed_experience.length).to eq(2)
          
          first_exp = parsed_experience.first
          expect(first_exp['company']).to eq('TechCorp Inc')
          expect(first_exp['position']).to eq('Senior Software Engineer')
          expect(first_exp['duration']).to eq('2020-Present')
          expect(first_exp['description']).to eq('Led development of microservices architecture')
          
          second_exp = parsed_experience.second
          expect(second_exp['company']).to eq('StartupXYZ')
          expect(second_exp['position']).to eq('Full Stack Developer')
          expect(second_exp['duration']).to eq('2018-2020')
          
          # Education validation (JSON array of objects)
          parsed_education = JSON.parse(resume.extracted_education)
          expect(parsed_education).to be_an(Array)
          expect(parsed_education.length).to eq(1)
          
          education = parsed_education.first
          expect(education['degree']).to eq('Bachelor of Science in Computer Science')
          expect(education['institution']).to eq('University of California')
          expect(education['year']).to eq('2018')
          
          # Step 7: Validate structured data access methods
          ai_data = resume.ai_extracted_data
          
          expect(ai_data[:name]).to eq('John Doe')
          expect(ai_data[:email]).to eq('john@example.com')
          expect(ai_data[:skills]).to eq(parsed_skills)
          expect(ai_data[:experience]).to eq(parsed_experience)
          expect(ai_data[:education]).to eq(parsed_education)
          
          # Step 8: Validate web interface displays processed data
          get "/resumes/#{resume.id}"
          
          expect(response).to have_http_status(:success)
          expect(response.body).to include('John Doe')
          expect(response.body).to include('john@example.com')
          expect(response.body).to include('TechCorp Inc')
          expect(response.body).to include('Ruby')
          expect(response.body).to include('University of California')
        end
      end
    end

    context 'AI service failure scenarios' do
      it 'handles HTTP timeout correctly' do
        Apartment::Tenant.switch(tenant.subdomain) do
          # Mock timeout scenario
          stub_request(:get, "http://ai-service:8000/health")
            .to_timeout
          
          resume = create(:resume, :with_file, user: user)
          
          perform_enqueued_jobs do
            ResumeProcessingJob.perform_now(resume.id, nil, 'ollama')
          end
          
          resume.reload
          
          expect(resume.status).to eq('failed')
          expect(resume.processing_status).to eq('failed')
          expect(resume.processing_error).to include('HTTP request timeout')
          expect(resume.has_ai_data?).to be false
        end
      end

      it 'handles malformed AI response correctly' do
        Apartment::Tenant.switch(tenant.subdomain) do
          # Mock malformed response
          stub_request(:get, "http://ai-service:8000/health")
            .to_return(status: 200, body: { status: "healthy" }.to_json)
          
          stub_request(:post, "http://ai-service:8000/extract")
            .to_return(
              status: 200,
              body: {
                "ai_response" => "Invalid JSON response without proper format",
                "confidence" => 0.5
              }.to_json
            )
          
          resume = create(:resume, :with_file, user: user)
          
          perform_enqueued_jobs do
            ResumeProcessingJob.perform_now(resume.id, nil, 'ollama')
          end
          
          resume.reload
          
          expect(resume.status).to eq('failed')
          expect(resume.processing_status).to eq('failed')
          expect(resume.processing_error).to include('Failed to parse AI response')
        end
      end

      it 'uses provider fallback when primary service fails' do
        Apartment::Tenant.switch(tenant.subdomain) do
          # Mock ollama service failure
          stub_request(:get, "http://ai-service:8000/health")
            .to_return(status: 500)
          
          # Mock basic service success
          stub_request(:get, "http://basic-ai:8080/health")
            .to_return(status: 200, body: { status: "healthy" }.to_json)
          
          stub_request(:post, "http://basic-ai:8080/extract")
            .to_return(ai_service_response)
          
          resume = create(:resume, :with_file, user: user)
          
          perform_enqueued_jobs do
            ResumeProcessingJob.perform_now(resume.id, nil, 'ollama')
          end
          
          resume.reload
          
          # Should succeed with fallback
          expect(resume.status).to eq('processed')
          expect(resume.processing_status).to eq('completed')
          expect(resume.extracted_name).to eq('John Doe')
          
          # Verify fallback was used
          expect(a_request(:get, "http://ai-service:8000/health")).to have_been_made
          expect(a_request(:get, "http://basic-ai:8080/health")).to have_been_made
          expect(a_request(:post, "http://basic-ai:8080/extract")).to have_been_made
        end
      end
    end

    context 'payload validation' do
      it 'sends correct request payload structure' do
        Apartment::Tenant.switch(tenant.subdomain) do
          resume = create(:resume, :with_file, user: user)
          
          perform_enqueued_jobs do
            ResumeProcessingJob.perform_now(resume.id, nil, 'ollama')
          end
          
          expect(a_request(:post, "http://ai-service:8000/extract")
            .with { |request|
              body = JSON.parse(request.body)
              
              # Validate required payload structure
              expect(body).to have_key('file_content')
              expect(body).to have_key('filename')
              expect(body).to have_key('processing_options')
              
              # Validate processing options
              options = body['processing_options']
              expect(options).to include('timeout' => 120)
              expect(options).to include('provider' => 'ollama')
              
              # Validate file content is base64 encoded
              expect(body['file_content']).to match(/^[A-Za-z0-9+\/]+=*$/)
              
              # Validate filename
              expect(body['filename']).to end_with('.pdf')
              
              true
            }
          ).to have_been_made.once
        end
      end

      it 'handles job description in payload when provided' do
        Apartment::Tenant.switch(tenant.subdomain) do
          job_description = create(:job_description, user: user, description: 'Senior Rails Developer position')
          resume = create(:resume, :with_file, user: user)
          
          perform_enqueued_jobs do
            ResumeProcessingJob.perform_now(resume.id, job_description.id, 'ollama')
          end
          
          expect(a_request(:post, "http://ai-service:8000/extract")
            .with { |request|
              body = JSON.parse(request.body)
              
              expect(body).to have_key('job_description')
              expect(body['job_description']).to eq('Senior Rails Developer position')
              
              true
            }
          ).to have_been_made.once
        end
      end
    end

    context 'performance validation' do
      it 'completes processing within acceptable time limits' do
        Apartment::Tenant.switch(tenant.subdomain) do
          resume = create(:resume, :with_file, user: user)
          
          start_time = Time.current
          
          perform_enqueued_jobs do
            ResumeProcessingJob.perform_now(resume.id, nil, 'ollama')
          end
          
          end_time = Time.current
          processing_duration = end_time - start_time
          
          resume.reload
          
          # Should complete within 2 minutes (actual test environment)
          expect(processing_duration).to be < 120.seconds
          
          # Should track processing time correctly
          expect(resume.processing_started_at).to be_present
          expect(resume.processing_completed_at).to be_present
          expect(resume.processing_completed_at).to be > resume.processing_started_at
        end
      end

      it 'handles concurrent processing correctly' do
        Apartment::Tenant.switch(tenant.subdomain) do
          resume1 = create(:resume, :with_file, user: user, title: 'Resume 1')
          resume2 = create(:resume, :with_file, user: user, title: 'Resume 2')
          
          # Process both resumes concurrently
          perform_enqueued_jobs do
            ResumeProcessingJob.perform_now(resume1.id, nil, 'ollama')
            ResumeProcessingJob.perform_now(resume2.id, nil, 'ollama')
          end
          
          resume1.reload
          resume2.reload
          
          # Both should complete successfully
          expect(resume1.status).to eq('processed')
          expect(resume2.status).to eq('processed')
          expect(resume1.extracted_name).to eq('John Doe')
          expect(resume2.extracted_name).to eq('John Doe')
          
          # Should have made separate API calls
          expect(a_request(:post, "http://ai-service:8000/extract")).to have_been_made.twice
        end
      end
    end

    context 'data integrity validation' do
      it 'maintains data consistency across multiple processing attempts' do
        Apartment::Tenant.switch(tenant.subdomain) do
          resume = create(:resume, :with_file, user: user)
          
          # First processing attempt
          perform_enqueued_jobs do
            ResumeProcessingJob.perform_now(resume.id, nil, 'ollama')
          end
          
          resume.reload
          first_name = resume.extracted_name
          first_skills_count = JSON.parse(resume.extracted_skills).length
          
          # Reprocessing should produce consistent results
          perform_enqueued_jobs do
            ResumeProcessingJob.perform_now(resume.id, nil, 'ollama')
          end
          
          resume.reload
          
          expect(resume.extracted_name).to eq(first_name)
          expect(JSON.parse(resume.extracted_skills).length).to eq(first_skills_count)
        end
      end

      it 'validates JSON structure integrity' do
        Apartment::Tenant.switch(tenant.subdomain) do
          resume = create(:resume, :with_file, user: user)
          
          perform_enqueued_jobs do
            ResumeProcessingJob.perform_now(resume.id, nil, 'ollama')
          end
          
          resume.reload
          
          # All JSON fields should be valid JSON
          expect { JSON.parse(resume.extracted_skills) }.not_to raise_error
          expect { JSON.parse(resume.extracted_experience) }.not_to raise_error
          expect { JSON.parse(resume.extracted_education) }.not_to raise_error
          
          # Skills should be array of strings
          skills = JSON.parse(resume.extracted_skills)
          expect(skills).to be_an(Array)
          skills.each { |skill| expect(skill).to be_a(String) }
          
          # Experience should be array of objects with required fields
          experience = JSON.parse(resume.extracted_experience)
          expect(experience).to be_an(Array)
          experience.each do |exp|
            expect(exp).to have_key('company')
            expect(exp).to have_key('position')
            expect(exp).to have_key('duration')
          end
          
          # Education should be array of objects with required fields
          education = JSON.parse(resume.extracted_education)
          expect(education).to be_an(Array)
          education.each do |edu|
            expect(edu).to have_key('degree')
            expect(edu).to have_key('institution')
          end
        end
      end
    end
  end
end
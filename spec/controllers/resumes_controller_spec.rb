# spec/controllers/resumes_controller_spec.rb
require 'rails_helper'

RSpec.describe ResumesController, type: :controller do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  
  before { sign_in user }

  describe 'GET #index' do
    let!(:user_resumes) { create_list(:resume, 3, user: user) }
    let!(:other_resumes) { create_list(:resume, 2, user: create(:user)) }

    it 'returns http success' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'assigns only current user resumes' do
      get :index
      expect(assigns(:resumes)).to match_array(user_resumes)
      expect(assigns(:resumes)).not_to include(*other_resumes)
    end

    it 'renders the index template' do
      get :index
      expect(response).to render_template(:index)
    end

    context 'when user is admin' do
      before { sign_in admin }

      it 'shows all resumes' do
        get :index
        expect(assigns(:resumes)).to match_array(user_resumes + other_resumes)
      end
    end
  end

  describe 'GET #show' do
    let(:resume) { create(:resume, :processed, user: user) }
    let(:other_user_resume) { create(:resume, user: create(:user)) }

    it 'returns http success for own resume' do
      get :show, params: { id: resume.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the resume' do
      get :show, params: { id: resume.id }
      expect(assigns(:resume)).to eq(resume)
    end

    it 'renders the show template' do
      get :show, params: { id: resume.id }
      expect(response).to render_template(:show)
    end

    it 'raises ActiveRecord::RecordNotFound for other user resume' do
      expect {
        get :show, params: { id: other_user_resume.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context 'when user is admin' do
      before { sign_in admin }

      it 'can view any resume' do
        get :show, params: { id: other_user_resume.id }
        expect(response).to have_http_status(:success)
        expect(assigns(:resume)).to eq(other_user_resume)
      end
    end
  end

  describe 'GET #new' do
    it 'returns http success' do
      get :new
      expect(response).to have_http_status(:success)
    end

    it 'assigns a new resume' do
      get :new
      expect(assigns(:resume)).to be_a_new(Resume)
      expect(assigns(:resume).user).to eq(user)
    end

    it 'renders the new template' do
      get :new
      expect(response).to render_template(:new)
    end
  end

  describe 'POST #create' do
    let(:file) { fixture_file_upload('spec/fixtures/files/sample_resume.pdf', 'application/pdf') }
    let(:valid_params) do
      {
        resume: {
          file: file
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new resume' do
        expect {
          post :create, params: valid_params
        }.to change(Resume, :count).by(1)
      end

      it 'assigns the resume to current user' do
        post :create, params: valid_params
        expect(Resume.last.user).to eq(user)
      end

      it 'enqueues processing job' do
        expect {
          post :create, params: valid_params
        }.to have_enqueued_job(ProcessResumeJob)
      end

      it 'redirects to resume show page' do
        post :create, params: valid_params
        expect(response).to redirect_to(resume_path(Resume.last))
      end

      it 'sets a success flash message' do
        post :create, params: valid_params
        expect(flash[:notice]).to eq('Resume was successfully uploaded and is being processed.')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          resume: {
            file: nil
          }
        }
      end

      it 'does not create a resume' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Resume, :count)
      end

      it 'renders the new template' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end

      it 'sets an error flash message' do
        post :create, params: invalid_params
        expect(flash.now[:alert]).to be_present
      end
    end
  end

  describe 'PATCH #update' do
    let(:resume) { create(:resume, :processed, user: user) }

    context 'with valid parameters' do
      let(:valid_params) do
        {
          id: resume.id,
          resume: {
            extracted_content: 'Updated content'
          }
        }
      end

      it 'updates the resume' do
        patch :update, params: valid_params
        resume.reload
        expect(resume.extracted_content).to eq('Updated content')
      end

      it 'redirects to resume show page' do
        patch :update, params: valid_params
        expect(response).to redirect_to(resume_path(resume))
      end

      it 'sets a success flash message' do
        patch :update, params: valid_params
        expect(flash[:notice]).to eq('Resume was successfully updated.')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          id: resume.id,
          resume: {
            extracted_content: nil
          }
        }
      end

      it 'does not update the resume' do
        original_content = resume.extracted_content
        patch :update, params: invalid_params
        resume.reload
        expect(resume.extracted_content).to eq(original_content)
      end

      it 'renders the show template' do
        patch :update, params: invalid_params
        expect(response).to render_template(:show)
      end
    end

    it 'prevents updating other user resumes' do
      other_resume = create(:resume, user: create(:user))
      expect {
        patch :update, params: { id: other_resume.id, resume: { extracted_content: 'Hacked' } }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'DELETE #destroy' do
    let!(:resume) { create(:resume, user: user) }

    it 'destroys the resume' do
      expect {
        delete :destroy, params: { id: resume.id }
      }.to change(Resume, :count).by(-1)
    end

    it 'redirects to resumes index' do
      delete :destroy, params: { id: resume.id }
      expect(response).to redirect_to(resumes_path)
    end

    it 'sets a success flash message' do
      delete :destroy, params: { id: resume.id }
      expect(flash[:notice]).to eq('Resume was successfully deleted.')
    end

    it 'prevents deleting other user resumes' do
      other_resume = create(:resume, user: create(:user))
      expect {
        delete :destroy, params: { id: other_resume.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST #process_resume' do
    let(:resume) { create(:resume, user: user) }

    it 'enqueues processing job' do
      expect {
        post :process_resume, params: { id: resume.id }
      }.to have_enqueued_job(ProcessResumeJob).with(resume.id)
    end

    it 'updates resume status to processing' do
      post :process_resume, params: { id: resume.id }
      resume.reload
      expect(resume.status).to eq('processing')
    end

    it 'redirects to resume show page' do
      post :process_resume, params: { id: resume.id }
      expect(response).to redirect_to(resume_path(resume))
    end

    it 'sets a success flash message' do
      post :process_resume, params: { id: resume.id }
      expect(flash[:notice]).to eq('Resume processing started.')
    end

    it 'prevents processing other user resumes' do
      other_resume = create(:resume, user: create(:user))
      expect {
        post :process_resume, params: { id: other_resume.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST #reprocess' do
    let(:resume) { create(:resume, :processed, user: user) }

    it 'enqueues processing job' do
      expect {
        post :reprocess, params: { id: resume.id }
      }.to have_enqueued_job(ProcessResumeJob).with(resume.id)
    end

    it 'updates resume status to processing' do
      post :reprocess, params: { id: resume.id }
      resume.reload
      expect(resume.status).to eq('processing')
    end

    it 'clears existing content' do
      post :reprocess, params: { id: resume.id }
      resume.reload
      expect(resume.extracted_content).to be_nil
      expect(resume.enhanced_content).to be_nil
      expect(resume.error_message).to be_nil
    end

    it 'redirects to resume show page' do
      post :reprocess, params: { id: resume.id }
      expect(response).to redirect_to(resume_path(resume))
    end

    it 'sets a success flash message' do
      post :reprocess, params: { id: resume.id }
      expect(flash[:notice]).to eq('Resume reprocessing started.')
    end
  end

  describe 'GET #download' do
    let(:resume) { create(:resume, user: user) }

    before do
      resume.file.attach(
        io: StringIO.new("PDF content"),
        filename: "test_resume.pdf",
        content_type: "application/pdf"
      )
    end

    it 'sends the file' do
      get :download, params: { id: resume.id }
      expect(response.headers['Content-Disposition']).to include('attachment')
      expect(response.headers['Content-Disposition']).to include('test_resume.pdf')
    end

    it 'sets correct content type' do
      get :download, params: { id: resume.id }
      expect(response.content_type).to eq('application/pdf')
    end

    it 'prevents downloading other user resumes' do
      other_resume = create(:resume, user: create(:user))
      expect {
        get :download, params: { id: other_resume.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'PATCH #update_content' do
    let(:resume) { create(:resume, :processed, user: user) }

    context 'updating extracted_content' do
      let(:params) do
        {
          id: resume.id,
          content_type: 'extracted',
          content: 'New extracted content'
        }
      end

      it 'updates the extracted content' do
        patch :update_content, params: params
        resume.reload
        expect(resume.extracted_content).to eq('New extracted content')
      end

      it 'returns success response' do
        patch :update_content, params: params
        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)['success']).to be true
      end
    end

    context 'updating enhanced_content' do
      let(:params) do
        {
          id: resume.id,
          content_type: 'enhanced',
          content: 'New enhanced content'
        }
      end

      it 'updates the enhanced content' do
        patch :update_content, params: params
        resume.reload
        expect(resume.enhanced_content).to eq('New enhanced content')
      end
    end

    context 'with invalid content_type' do
      let(:params) do
        {
          id: resume.id,
          content_type: 'invalid',
          content: 'Some content'
        }
      end

      it 'returns error response' do
        patch :update_content, params: params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['error']).to be_present
      end
    end

    it 'prevents updating other user resumes' do
      other_resume = create(:resume, user: create(:user))
      expect {
        patch :update_content, params: { 
          id: other_resume.id, 
          content_type: 'extracted', 
          content: 'Hacked' 
        }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context 'when user is not signed in' do
    before { sign_out user }

    it 'redirects to sign in for index' do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for show' do
      resume = create(:resume)
      get :show, params: { id: resume.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for create' do
      post :create, params: { resume: { file: nil } }
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
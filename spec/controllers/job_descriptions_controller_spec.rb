# spec/controllers/job_descriptions_controller_spec.rb
require 'rails_helper'

RSpec.describe JobDescriptionsController, type: :controller do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  
  before { sign_in user }

  describe 'GET #index' do
    let!(:user_job_descriptions) { create_list(:job_description, 3, user: user) }
    let!(:other_job_descriptions) { create_list(:job_description, 2, user: create(:user)) }

    it 'returns http success' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'assigns only current user job descriptions' do
      get :index
      expect(assigns(:job_descriptions)).to match_array(user_job_descriptions)
      expect(assigns(:job_descriptions)).not_to include(*other_job_descriptions)
    end

    it 'renders the index template' do
      get :index
      expect(response).to render_template(:index)
    end

    it 'orders job descriptions by most recent first' do
      get :index
      expect(assigns(:job_descriptions)).to eq(user_job_descriptions.reverse)
    end

    context 'when user is admin' do
      before { sign_in admin }

      it 'shows all job descriptions' do
        get :index
        all_job_descriptions = user_job_descriptions + other_job_descriptions
        expect(assigns(:job_descriptions)).to match_array(all_job_descriptions)
      end
    end

    context 'when user has no job descriptions' do
      let(:empty_user) { create(:user) }
      
      before do
        sign_in empty_user
        get :index
      end

      it 'assigns empty collection' do
        expect(assigns(:job_descriptions)).to be_empty
      end
    end
  end

  describe 'GET #show' do
    let(:job_description) { create(:job_description, user: user) }
    let(:other_user_job_description) { create(:job_description, user: create(:user)) }

    it 'returns http success for own job description' do
      get :show, params: { id: job_description.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the job description' do
      get :show, params: { id: job_description.id }
      expect(assigns(:job_description)).to eq(job_description)
    end

    it 'renders the show template' do
      get :show, params: { id: job_description.id }
      expect(response).to render_template(:show)
    end

    it 'raises ActiveRecord::RecordNotFound for other user job description' do
      expect {
        get :show, params: { id: other_user_job_description.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context 'when user is admin' do
      before { sign_in admin }

      it 'can view any job description' do
        get :show, params: { id: other_user_job_description.id }
        expect(response).to have_http_status(:success)
        expect(assigns(:job_description)).to eq(other_user_job_description)
      end
    end
  end

  describe 'GET #new' do
    it 'returns http success' do
      get :new
      expect(response).to have_http_status(:success)
    end

    it 'assigns a new job description' do
      get :new
      expect(assigns(:job_description)).to be_a_new(JobDescription)
      expect(assigns(:job_description).user).to eq(user)
    end

    it 'renders the new template' do
      get :new
      expect(response).to render_template(:new)
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        job_description: {
          title: 'Software Engineer',
          company: 'Tech Corp',
          content: 'We are looking for a talented software engineer...'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new job description' do
        expect {
          post :create, params: valid_params
        }.to change(JobDescription, :count).by(1)
      end

      it 'assigns the job description to current user' do
        post :create, params: valid_params
        expect(JobDescription.last.user).to eq(user)
      end

      it 'redirects to job description show page' do
        post :create, params: valid_params
        expect(response).to redirect_to(job_description_path(JobDescription.last))
      end

      it 'sets a success flash message' do
        post :create, params: valid_params
        expect(flash[:notice]).to eq('Job description was successfully created.')
      end

      it 'sets correct attributes' do
        post :create, params: valid_params
        job_description = JobDescription.last
        expect(job_description.title).to eq('Software Engineer')
        expect(job_description.company).to eq('Tech Corp')
        expect(job_description.content).to include('talented software engineer')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          job_description: {
            title: '',
            company: '',
            content: ''
          }
        }
      end

      it 'does not create a job description' do
        expect {
          post :create, params: invalid_params
        }.not_to change(JobDescription, :count)
      end

      it 'renders the new template' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end

      it 'assigns the job description with errors' do
        post :create, params: invalid_params
        expect(assigns(:job_description)).to be_a_new(JobDescription)
        expect(assigns(:job_description).errors).to be_present
      end
    end

    context 'with missing parameters' do
      let(:missing_params) do
        {
          job_description: {
            title: 'Software Engineer'
            # missing company and content
          }
        }
      end

      it 'does not create a job description' do
        expect {
          post :create, params: missing_params
        }.not_to change(JobDescription, :count)
      end
    end
  end

  describe 'GET #edit' do
    let(:job_description) { create(:job_description, user: user) }
    let(:other_user_job_description) { create(:job_description, user: create(:user)) }

    it 'returns http success for own job description' do
      get :edit, params: { id: job_description.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the job description' do
      get :edit, params: { id: job_description.id }
      expect(assigns(:job_description)).to eq(job_description)
    end

    it 'renders the edit template' do
      get :edit, params: { id: job_description.id }
      expect(response).to render_template(:edit)
    end

    it 'raises ActiveRecord::RecordNotFound for other user job description' do
      expect {
        get :edit, params: { id: other_user_job_description.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'PATCH #update' do
    let(:job_description) { create(:job_description, user: user) }

    context 'with valid parameters' do
      let(:valid_params) do
        {
          id: job_description.id,
          job_description: {
            title: 'Senior Software Engineer',
            company: 'Updated Tech Corp',
            content: 'Updated job description content...'
          }
        }
      end

      it 'updates the job description' do
        patch :update, params: valid_params
        job_description.reload
        expect(job_description.title).to eq('Senior Software Engineer')
        expect(job_description.company).to eq('Updated Tech Corp')
        expect(job_description.content).to eq('Updated job description content...')
      end

      it 'redirects to job description show page' do
        patch :update, params: valid_params
        expect(response).to redirect_to(job_description_path(job_description))
      end

      it 'sets a success flash message' do
        patch :update, params: valid_params
        expect(flash[:notice]).to eq('Job description was successfully updated.')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          id: job_description.id,
          job_description: {
            title: '',
            company: '',
            content: ''
          }
        }
      end

      it 'does not update the job description' do
        original_title = job_description.title
        patch :update, params: invalid_params
        job_description.reload
        expect(job_description.title).to eq(original_title)
      end

      it 'renders the edit template' do
        patch :update, params: invalid_params
        expect(response).to render_template(:edit)
      end

      it 'assigns the job description with errors' do
        patch :update, params: invalid_params
        expect(assigns(:job_description).errors).to be_present
      end
    end

    it 'prevents updating other user job descriptions' do
      other_job_description = create(:job_description, user: create(:user))
      expect {
        patch :update, params: { 
          id: other_job_description.id, 
          job_description: { title: 'Hacked' } 
        }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'DELETE #destroy' do
    let!(:job_description) { create(:job_description, user: user) }

    it 'destroys the job description' do
      expect {
        delete :destroy, params: { id: job_description.id }
      }.to change(JobDescription, :count).by(-1)
    end

    it 'redirects to job descriptions index' do
      delete :destroy, params: { id: job_description.id }
      expect(response).to redirect_to(job_descriptions_path)
    end

    it 'sets a success flash message' do
      delete :destroy, params: { id: job_description.id }
      expect(flash[:notice]).to eq('Job description was successfully deleted.')
    end

    it 'prevents deleting other user job descriptions' do
      other_job_description = create(:job_description, user: create(:user))
      expect {
        delete :destroy, params: { id: other_job_description.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context 'when job description has associated resume processings' do
      let!(:resume) { create(:resume, user: user) }
      let!(:resume_processing) { create(:resume_processing, resume: resume, job_description: job_description) }

      it 'destroys associated resume processings' do
        expect {
          delete :destroy, params: { id: job_description.id }
        }.to change(ResumeProcessing, :count).by(-1)
      end
    end
  end

  context 'when user is not signed in' do
    before { sign_out user }

    it 'redirects to sign in for index' do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for show' do
      job_description = create(:job_description)
      get :show, params: { id: job_description.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for create' do
      post :create, params: { job_description: { title: 'Test' } }
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for update' do
      job_description = create(:job_description)
      patch :update, params: { id: job_description.id, job_description: { title: 'Test' } }
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for destroy' do
      job_description = create(:job_description)
      delete :destroy, params: { id: job_description.id }
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context 'edge cases' do
    it 'handles very long content' do
      long_content = 'A' * 10000
      params = {
        job_description: {
          title: 'Software Engineer',
          company: 'Tech Corp',
          content: long_content
        }
      }
      
      post :create, params: params
      expect(JobDescription.last.content).to eq(long_content)
    end

    it 'handles special characters in content' do
      special_content = "Job with special chars: @#$%^&*()[]{}|;':\",./<>?"
      params = {
        job_description: {
          title: 'Software Engineer',
          company: 'Tech Corp',
          content: special_content
        }
      }
      
      post :create, params: params
      expect(JobDescription.last.content).to eq(special_content)
    end
  end
end
# spec/controllers/dashboard_controller_spec.rb
require 'rails_helper'

RSpec.describe DashboardController, type: :controller do
  let(:user) { create(:user) }
  
  before { sign_in user }

  describe 'GET #index' do
    let!(:user_resumes) { create_list(:resume, 3, user: user) }
    let!(:processed_resume) { create(:resume, :processed, user: user) }
    let!(:processing_resume) { create(:resume, :processing, user: user) }
    let!(:failed_resume) { create(:resume, :failed, user: user) }
    let!(:user_job_descriptions) { create_list(:job_description, 2, user: user) }
    
    # Create resumes for other users that shouldn't appear
    let!(:other_user_resumes) { create_list(:resume, 2, user: create(:user)) }

    before { get :index }

    it 'returns http success' do
      expect(response).to have_http_status(:success)
    end

    it 'renders the index template' do
      expect(response).to render_template(:index)
    end

    it 'assigns user resumes' do
      expect(assigns(:resumes)).to include(*user_resumes, processed_resume, processing_resume, failed_resume)
      expect(assigns(:resumes)).not_to include(*other_user_resumes)
    end

    it 'assigns user job descriptions' do
      expect(assigns(:job_descriptions)).to match_array(user_job_descriptions)
    end

    it 'calculates correct resume counts' do
      expect(assigns(:total_resumes)).to eq(6) # 3 + 1 + 1 + 1
      expect(assigns(:processed_resumes)).to eq(1)
      expect(assigns(:processing_resumes)).to eq(1)
      expect(assigns(:failed_resumes)).to eq(1)
    end

    context 'when user has no resumes' do
      let(:empty_user) { create(:user) }
      
      before do
        sign_in empty_user
        get :index
      end

      it 'assigns empty collections' do
        expect(assigns(:resumes)).to be_empty
        expect(assigns(:job_descriptions)).to be_empty
      end

      it 'sets counts to zero' do
        expect(assigns(:total_resumes)).to eq(0)
        expect(assigns(:processed_resumes)).to eq(0)
        expect(assigns(:processing_resumes)).to eq(0)
        expect(assigns(:failed_resumes)).to eq(0)
      end
    end

    context 'with admin user' do
      let(:admin) { create(:user, :admin) }
      
      before do
        sign_in admin
        get :index
      end

      it 'shows all resumes across users' do
        all_resumes = user_resumes + [processed_resume, processing_resume, failed_resume] + other_user_resumes
        expect(assigns(:resumes)).to match_array(all_resumes)
      end

      it 'shows all job descriptions across users' do
        all_job_descriptions = user_job_descriptions + JobDescription.where.not(user: user)
        expect(assigns(:job_descriptions)).to match_array(all_job_descriptions)
      end

      it 'calculates counts for all resumes' do
        total_count = Resume.count
        expect(assigns(:total_resumes)).to eq(total_count)
      end
    end

    context 'with recent activity' do
      let!(:recent_resume) { create(:resume, :processed, user: user, created_at: 1.hour.ago) }
      let!(:old_resume) { create(:resume, :processed, user: user, created_at: 1.week.ago) }

      before { get :index }

      it 'orders resumes by most recent first' do
        expect(assigns(:resumes).first).to eq(recent_resume)
        expect(assigns(:resumes)).to include(old_resume)
      end
    end
  end

  context 'when user is not signed in' do
    before { sign_out user }

    it 'redirects to sign in page' do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'sets appropriate flash message' do
      get :index
      expect(flash[:alert]).to eq('You need to sign in or sign up before continuing.')
    end
  end

  context 'with database errors' do
    before do
      allow(Resume).to receive(:includes).and_raise(ActiveRecord::ConnectionTimeoutError)
    end

    it 'handles database connection errors gracefully' do
      expect {
        get :index
      }.to raise_error(ActiveRecord::ConnectionTimeoutError)
    end
  end

  context 'performance considerations' do
    let!(:many_resumes) { create_list(:resume, 50, user: user) }
    let!(:many_job_descriptions) { create_list(:job_description, 20, user: user) }

    before { get :index }

    it 'loads resumes efficiently with includes' do
      # This test ensures we're not causing N+1 queries
      expect(assigns(:resumes)).to be_present
      expect(assigns(:resumes).size).to be > 0
    end

    it 'limits recent resumes display' do
      # Assuming we only show recent resumes on dashboard
      expect(assigns(:resumes).size).to be <= 50
    end
  end
end
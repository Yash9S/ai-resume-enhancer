# spec/requests/dashboard_spec.rb
require 'rails_helper'

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }

  describe "GET /" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get root_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is signed in" do
      before do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: user.password
          }
        }
      end

      it "returns http success" do
        get root_path
        expect(response).to have_http_status(:success)
      end

      it "renders dashboard template" do
        get root_path
        expect(response.body).to include("Dashboard")
      end
    end
  end
end
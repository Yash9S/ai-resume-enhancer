# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  subject { build(:user) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(subject).to be_valid
    end

    it 'requires an email' do
      subject.email = nil
      expect(subject).not_to be_valid
    end

    it 'requires a unique email' do
      create(:user, email: 'test@example.com')
      subject.email = 'test@example.com'
      expect(subject).not_to be_valid
    end
  end

  describe 'associations' do
    it { should have_many(:resumes).dependent(:destroy) }
    it { should have_many(:job_descriptions).dependent(:destroy) }
    it { should have_many(:resume_processings).through(:resumes) }
  end

  describe 'enums' do
    it { should define_enum_for(:role).with_values(user: 0, admin: 1) }
  end

  describe 'default role' do
    it 'sets default role to user' do
      user = User.new
      expect(user.role).to eq('user')
    end
  end
end
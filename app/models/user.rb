class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Define user roles
  enum :role, { user: 0, admin: 1 }

  # Note: These associations don't work across schemas in multi-tenant setup
  # Use the custom methods below instead: user.resumes_in_current_tenant
  # has_many :resumes, dependent: :destroy
  # has_many :job_descriptions, dependent: :destroy
  # has_many :resume_processings, through: :resumes
  
  # Multitenancy support
  belongs_to :tenant, optional: true

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :role, presence: true

  # Scopes for future multitenancy
  # scope :for_tenant, ->(tenant) { where(tenant: tenant) }

  # Default role
  after_initialize :set_default_role, if: :new_record?

  def admin?
    role == 'admin'
  end

  def user?
    role == 'user'
  end

  # Cross-schema methods for multi-tenant setup with safe tenant switching
  def resumes_in_current_tenant
    return Resume.none unless safe_current_tenant
    
    Resume.where(user_id: id)
  rescue => e
    Rails.logger.error "Error accessing resumes in current tenant: #{e.message}"
    Resume.none
  end

  def job_descriptions_in_current_tenant
    return JobDescription.none unless safe_current_tenant
    
    JobDescription.where(user_id: id)
  rescue => e
    Rails.logger.error "Error accessing job descriptions in current tenant: #{e.message}"
    JobDescription.none
  end

  def resume_processings_in_current_tenant
    return ResumeProcessing.none unless safe_current_tenant
    
    ResumeProcessing.joins(:resume).where(resumes: { user_id: id })
  rescue => e
    Rails.logger.error "Error accessing resume processings in current tenant: #{e.message}"
    ResumeProcessing.none
  end

  # Safe method to get current tenant without crashing
  def safe_current_tenant
    begin
      Apartment::Tenant.current
    rescue => e
      Rails.logger.warn "Error getting current tenant: #{e.message}"
      nil
    end
  end

  private

  def set_default_role
    self.role ||= :user
  end
end
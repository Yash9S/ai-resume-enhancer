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

  # Cross-schema methods for multi-tenant setup
  def resumes_in_current_tenant
    return Resume.none unless Apartment::Tenant.current
    
    Resume.where(user_id: id)
  end

  def job_descriptions_in_current_tenant
    return JobDescription.none unless Apartment::Tenant.current
    
    JobDescription.where(user_id: id)
  end

  def resume_processings_in_current_tenant
    return ResumeProcessing.none unless Apartment::Tenant.current
    
    ResumeProcessing.joins(:resume).where(resumes: { user_id: id })
  end

  private

  def set_default_role
    self.role ||= :user
  end
end
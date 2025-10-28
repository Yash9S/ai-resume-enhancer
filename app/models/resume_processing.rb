class ResumeProcessing < ApplicationRecord
  belongs_to :resume
  belongs_to :job_description, optional: true
  # Note: Users are in public schema, so we store user_id but don't enforce FK constraint

  validates :processing_type, presence: true

  enum :processing_type, { extraction: 0, enhancement: 1, matching: 2 }
  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }

  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(status: :completed) }
  scope :for_current_tenant, -> { all } # Already tenant-scoped via apartment gem

  # Get user from public schema (cross-schema relationship) with safe tenant switching
  def user
    return nil unless user_id
    
    begin
      Apartment::Tenant.switch('public') do
        User.find_by(id: user_id)
      end
    rescue => e
      Rails.logger.error "Error switching to public schema to get user: #{e.message}"
      # Fallback: try to get user without switching
      begin
        User.find_by(id: user_id)
      rescue => fallback_error
        Rails.logger.error "Fallback user lookup failed: #{fallback_error.message}"
        nil
      end
    end
  end
  
  # Set user (for compatibility with existing code)
  def user=(user_obj)
    self.user_id = user_obj&.id
  end

  def processing_time
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  def success?
    status == 'completed'
  end

  # Tenant-aware method to get current tenant context with error handling
  def current_tenant
    begin
      Apartment::Tenant.current
    rescue => e
      Rails.logger.warn "Error getting current tenant: #{e.message}"
      nil
    end
  end
end
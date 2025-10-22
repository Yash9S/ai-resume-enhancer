class Resume < ApplicationRecord
  # Note: Users are in public schema, so we store user_id but don't enforce FK constraint
  # Use delegate to access user properties across schemas
  has_many :resume_processings, dependent: :destroy
  has_one_attached :file

  validates :title, presence: true
  validates :file, presence: true
  validate :acceptable_file_type

  enum :status, { uploaded: 0, processing: 1, processed: 2, failed: 3 }
  enum :processing_status, { 
    pending: 0, 
    queued: 1, 
    processing: 2, 
    completed: 3, 
    failed: 4 
  }, prefix: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_current_tenant, -> { all } # Already tenant-scoped via apartment gem
  scope :ai_processed, -> { where(processing_status: 'completed') }
  scope :needs_processing, -> { where(processing_status: ['pending', 'failed']) }

  # Get user from public schema (cross-schema relationship)
  def user
    return nil unless user_id
    
    # Temporarily switch to public schema to get user
    Apartment::Tenant.switch('public') do
      User.find_by(id: user_id)
    end
  end
  
  # Set user (for compatibility with existing code)
  def user=(user_obj)
    self.user_id = user_obj&.id
  end

  def processed?
    status == 'processed'
  end

  def file_size
    file.attached? ? file.byte_size : 0
  end

  # Check if processing is taking too long (over 3 minutes)
  def processing_timeout?
    return false unless processing_started_at
    return false if processing_status_completed? || processing_status_failed?
    
    Time.current - processing_started_at > 3.minutes
  end

  # Reset stuck processing jobs
  def reset_if_timeout!
    if processing_timeout?
      Rails.logger.warn "⏰ Resetting stuck processing for resume #{id}"
      update!(
        processing_status: 'pending',
        processing_error: 'Processing timeout - reset for retry',
        processing_started_at: nil
      )
      true
    else
      false
    end
  end

  # AI Processing Methods
  def process_with_ai!(job_description_id = nil, ai_provider = 'ollama')
    self.update!(processing_status: 'queued')
    ResumeProcessingJob.perform_later(self.id, job_description_id, ai_provider)
  end

  # Tenant-aware method to get current tenant context
  def current_tenant
    Apartment::Tenant.current
  end

  def file_name
    file.attached? ? file.filename.to_s : 'No file attached'
  end



  def ai_extracted_data
    {
      name: extracted_name,
      email: extracted_email,
      phone: extracted_phone,
      location: extracted_location,
      summary: extracted_summary,
      skills: extracted_skills ? JSON.parse(extracted_skills) : [],
      experience: extracted_experience ? JSON.parse(extracted_experience) : [],
      education: extracted_education ? JSON.parse(extracted_education) : []
    }
  end

  def has_ai_data?
    extracted_name.present? || extracted_email.present? || extracted_text.present?
  end

  def processing_time
    return nil unless processing_started_at && processing_completed_at
    (processing_completed_at - processing_started_at).to_i
  end

  private

  def acceptable_file_type
    return unless file.attached?

    acceptable_types = %w[application/pdf application/vnd.openxmlformats-officedocument.wordprocessingml.document]
    unless acceptable_types.include?(file.content_type)
      errors.add(:file, 'must be a PDF or DOCX file')
    end
  end
end
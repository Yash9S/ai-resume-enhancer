class ResumesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_resume, only: [:show, :edit, :update, :destroy, :process_resume, :reprocess, :download, :update_content, :process_ai, :ai_status]

  # get all the resumes
  def index
    @resumes = current_user.resumes.includes(:resume_processings)
                          .page(params[:page])
                          .per(10)
                          .order(created_at: :desc)
  end

  # get a single resume with id
  def show
    @job_descriptions = current_user.job_descriptions.recent
    @processings = @resume.resume_processings.recent
  end

  # get a new resume form
  def new
    @resume = current_user.resumes.build
  end

  # create a new resume
  def create
    @resume = current_user.resumes.build(resume_params)
    
    if @resume.save
      redirect_to @resume, notice: 'Resume was successfully uploaded.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # get a resume edit form
  def edit
  end

  # update a resume
  def update
    if @resume.update(resume_params)
      redirect_to @resume, notice: 'Resume was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # delete a resume
  def destroy
    @resume.destroy
    redirect_to resumes_path, notice: 'Resume was successfully deleted.'
  end

  def process_resume
    job_description_id = params[:job_description_id].present? ? params[:job_description_id] : nil
    ai_provider = params[:ai_provider] || 'ollama'
    
    # Update status to processing
    @resume.update!(
      status: :processing,
      processing_status: :processing,
      processing_error: nil,
      processing_started_at: Time.current
    )
    
    # Queue background job for processing with current tenant
    current_tenant = Apartment::Tenant.current
    ResumeProcessingJob.perform_later(@resume.id, job_description_id, ai_provider, current_tenant)
    
    redirect_to @resume, notice: 'Resume processing started in background. You will be notified when completed.'
  end

  def reprocess
    job_description_id = params[:job_description_id]
    ai_provider = params[:ai_provider] || 'ollama'
    
    # Force reprocessing and clear existing data
    @resume.update!(
      status: :processing,
      processing_status: :processing,
      processing_error: nil,
      processing_started_at: Time.current,
      processing_completed_at: nil,
      extracted_content: nil,
      enhanced_content: nil,
      extracted_data: nil,
      # Clear extracted fields for fresh processing
      extracted_name: nil,
      extracted_email: nil,
      extracted_phone: nil,
      extracted_location: nil,
      extracted_summary: nil,
      extracted_skills: nil,
      extracted_experience: nil,
      extracted_education: nil,
      extracted_text: nil,
      extraction_confidence: nil
    )
    
    # Queue background job for reprocessing with current tenant
    current_tenant = Apartment::Tenant.current
    ResumeProcessingJob.perform_later(@resume.id, job_description_id, ai_provider, current_tenant)
    
    redirect_to @resume, notice: 'Resume reprocessing started in background. You will be notified when completed.'
  end

  def download
    case params[:format]&.downcase
    when 'pdf'
      send_pdf
    when 'txt'
      send_text
    else
      send_original
    end
  end

  def update_content
    content_type = params[:content_type] # 'extracted' or 'enhanced'
    content = params[:content]
    
    case content_type
    when 'extracted'
      @resume.update(extracted_content: content)
    when 'enhanced'
      @resume.update(enhanced_content: content)
    end
    
    render json: { success: true, message: 'Content updated successfully' }
  rescue => e
    render json: { success: false, message: e.message }, status: :unprocessable_entity
  end

  # NEW AI PROCESSING METHODS
  def process_ai
    ai_provider = params[:ai_provider] || 'ollama'
    job_description_id = params[:job_description_id]
    
    # Validate AI provider
    ai_service = AiExtractionService.new
    available_providers = ai_service.available_providers
    
    unless available_providers&.dig('providers', ai_provider)
      return render json: { error: "AI provider '#{ai_provider}' is not available" }, 
                   status: :unprocessable_entity
    end
    
    # Validate job description if provided
    if job_description_id.present?
      job_description = current_user.job_descriptions.find_by(id: job_description_id)
      unless job_description
        return render json: { error: "Job description not found" }, status: :not_found
      end
    end
    
    # Start AI processing
    begin
      @resume.process_with_ai!(job_description_id, ai_provider)
      render json: { 
        success: true, 
        message: 'AI processing started',
        processing_status: @resume.processing_status
      }
    rescue => e
      Rails.logger.error "Failed to start AI processing: #{e.message}"
      render json: { error: "Failed to start AI processing: #{e.message}" }, 
             status: :unprocessable_entity
    end
  end

  def ai_status
    ai_data = @resume.has_ai_data? ? @resume.ai_extracted_data : nil
    
    render json: {
      processing_status: @resume.processing_status,
      processing_started_at: @resume.processing_started_at,
      processing_completed_at: @resume.processing_completed_at,
      processing_error: @resume.processing_error,
      ai_provider_used: @resume.ai_provider_used,
      extraction_confidence: @resume.extraction_confidence,
      processing_time: @resume.processing_time,
      ai_data: ai_data
    }
  end

  private

  def set_resume
    @resume = current_user.resumes.find(params[:id])
  end

  def resume_params
    params.require(:resume).permit(:title, :file)
  end

  def send_pdf
    # Implement PDF generation logic here
    # You might want to use gems like Prawn or wicked_pdf
    send_data generate_pdf_content, 
              filename: "#{@resume.title.parameterize}.pdf",
              type: 'application/pdf'
  end

  def send_text
    content = @resume.enhanced_content.presence || 
              @resume.extracted_content.presence || 
              @resume.original_content || 
              'No content available'
              
    send_data content,
              filename: "#{@resume.title.parameterize}.txt",
              type: 'text/plain'
  end

  def send_original
    if @resume.file.attached?
      redirect_to rails_blob_path(@resume.file, disposition: "attachment")
    else
      redirect_to @resume, alert: 'Original file not available'
    end
  end

  def generate_pdf_content
    # Basic PDF generation - implement with PDF library
    content = @resume.enhanced_content.presence || 
              @resume.extracted_content.presence || 
              'Resume content not available'
              
    # For now, return simple text - implement proper PDF generation
    "Resume: #{@resume.title}\n\n#{content}"
  end
end
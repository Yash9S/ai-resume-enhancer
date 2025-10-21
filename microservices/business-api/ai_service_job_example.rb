# Job to process resumes using the AI Extraction Service

class ProcessResumeWithAIServiceJob < ApplicationJob
  queue_as :default

  def perform(resume, job_description = nil, user = nil)
    user ||= resume.user
    
    processing = ResumeProcessing.create!(
      resume: resume,
      job_description: job_description,
      user: user,
      processing_type: job_description ? :matching : :extraction,
      status: :processing,
      started_at: Time.current
    )

    begin
      ai_service = AIExtractionService.new
      
      # Step 1: Extract structured data if needed
      if needs_extraction?(resume)
        Rails.logger.info "Sending resume to AI service for extraction", resume_id: resume.id
        
        extraction_result = ai_service.extract_structured_data(
          file: resume.file,
          job_id: processing.id.to_s
        )
        
        if extraction_result['success']
          resume.update!(
            original_content: extraction_result['original_text'],
            extracted_content: extraction_result['structured_data']['summary'] || extraction_result['original_text'],
            extracted_data: extraction_result['structured_data'],
            status: :processed
          )
        else
          handle_error(processing, extraction_result['error'] || 'AI extraction failed')
          return
        end
      end

      # Step 2: Enhance content if job description provided
      if job_description
        Rails.logger.info "Enhancing resume content for job matching", resume_id: resume.id
        
        enhancement_result = ai_service.enhance_content(
          resume_content: resume.extracted_content || resume.original_content,
          job_description: job_description.content,
          job_id: processing.id.to_s
        )
        
        if enhancement_result['success']
          resume.update!(enhanced_content: enhancement_result['enhanced_content'])
          
          processing.update!(
            result: enhancement_result['suggestions']&.join("\n"),
            match_score: enhancement_result['match_score'],
            ai_response: enhancement_result
          )
        else
          Rails.logger.warn "Enhancement failed, continuing with extraction only"
        end
      end

      processing.update!(
        status: :completed,
        completed_at: Time.current
      )

      Rails.logger.info "Resume processing completed via AI service", 
                       resume_id: resume.id, processing_id: processing.id
      
    rescue => e
      handle_error(processing, e.message)
      Rails.logger.error "AI service processing failed", 
                        error: e.message, resume_id: resume.id
    end
  end

  private

  def needs_extraction?(resume)
    resume.extracted_content.blank? || 
    resume.extracted_content.include?("Error") ||
    resume.extracted_content.length < 100
  end

  def handle_error(processing, error_message)
    processing.update!(
      status: :failed,
      result: "Processing failed: #{error_message}",
      completed_at: Time.current
    )
    
    processing.resume.update!(status: :failed)
  end
end

# Service class to communicate with AI Extraction Service
class AIExtractionService
  include HTTParty
  
  base_uri ENV['AI_EXTRACTION_SERVICE_URL'] || 'http://localhost:8001'
  
  def extract_structured_data(file:, job_id:)
    # Create multipart form data
    options = {
      body: {
        file: file_to_upload_io(file),
        job_id: job_id
      }
    }
    
    response = self.class.post('/extract/structured', options)
    
    if response.success?
      response.parsed_response
    else
      { 'success' => false, 'error' => "AI service error: #{response.code}" }
    end
  rescue => e
    Rails.logger.error "Failed to call AI extraction service: #{e.message}"
    { 'success' => false, 'error' => e.message }
  end
  
  def enhance_content(resume_content:, job_description: nil, job_id:)
    options = {
      body: {
        resume_content: resume_content,
        job_description: job_description,
        job_id: job_id
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    }
    
    response = self.class.post('/enhance', options)
    
    if response.success?
      response.parsed_response
    else
      { 'success' => false, 'error' => "AI service error: #{response.code}" }
    end
  rescue => e
    Rails.logger.error "Failed to call AI enhancement service: #{e.message}"
    { 'success' => false, 'error' => e.message }
  end
  
  private
  
  def file_to_upload_io(active_storage_file)
    # Convert ActiveStorage file to UploadIO for HTTParty
    tempfile = active_storage_file.download
    UploadIO.new(
      StringIO.new(tempfile),
      active_storage_file.content_type,
      active_storage_file.filename.to_s
    )
  end
end
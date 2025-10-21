class ProcessResumeJob < ApplicationJob
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
      service = ResumeParsingService.new(resume)
      
      # Extract content if not properly processed
      needs_extraction = resume.extracted_content.blank? || 
                        resume.extracted_content.include?("I can't help") ||
                        resume.extracted_content.include?("Error") ||
                        resume.extracted_content.include?("Unable to extract") ||
                        resume.extracted_content.length < 100
                        
      if needs_extraction
        Rails.logger.info "Re-extracting content for resume #{resume.id}"
        extraction_result = service.extract_content
        
        if extraction_result[:error]
          handle_error(processing, extraction_result[:error])
          return
        end
        
        resume.update!(
          original_content: extraction_result[:original_text],
          extracted_content: extraction_result[:summary] || extraction_result[:original_text],
          extracted_data: extraction_result[:extracted_data],
          status: :processed
        )
      else
        Rails.logger.info "Resume #{resume.id} already has valid extracted content"
      end

      # If job description provided, enhance content and calculate match score
      if job_description
        enhancement_result = service.enhance_content(job_description)
        match_score = service.calculate_match_score(job_description)
        
        unless enhancement_result[:error]
          resume.update!(enhanced_content: enhancement_result[:enhanced_content])
        end
        
        processing.update!(
          result: enhancement_result[:suggestions]&.join("\n"),
          match_score: match_score,
          ai_response: {
            enhancement: enhancement_result,
            match_score: match_score
          }
        )
      end

      processing.update!(
        status: :completed,
        completed_at: Time.current
      )

      # Update resume status to processed if extraction was successful
      if resume.extracted_content.present? && !resume.extracted_content.include?("Error")
        resume.update!(status: :processed)
      end

      # Send notification (you could implement email notifications here)
      Rails.logger.info "Resume processing completed for user #{user.id}, resume #{resume.id}"
      
    rescue => e
      handle_error(processing, e.message)
      Rails.logger.error "Resume processing failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  private

  def handle_error(processing, error_message)
    processing.update!(
      status: :failed,
      error_message: error_message,
      completed_at: Time.current
    )
    
    processing.resume.update!(status: :failed)
  end
end
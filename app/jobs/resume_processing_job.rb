require 'timeout'

class ResumeProcessingJob < ApplicationJob
  queue_as :default
  
  # Limited retry for better user experience - fail fast and show results
  retry_on Timeout::Error, Net::ReadTimeout, attempts: 2, wait: 10.seconds
  retry_on StandardError, attempts: 1, wait: 5.seconds
  
  # Ensure job completes within 3 minutes maximum
  def self.timeout
    3.minutes
  end

  def perform(resume_id, job_description_id = nil, ai_provider = 'ollama')
    start_time = Time.current
    resume = Resume.find(resume_id)
    job_description = job_description_id ? JobDescription.find(job_description_id) : nil
    
    ai_service = AiExtractionService.new
    
    # Update resume status immediately
    resume.update!(
      processing_status: 'processing',
      processing_started_at: start_time
    )
    
    Rails.logger.info "🚀 Starting fast AI processing for resume #{resume.id} with #{ai_provider}"
    
    begin
      # Try AI service health check with short timeout
      health_status = nil
      begin
        Timeout::timeout(5) do
          health_status = ai_service.health_check
        end
      rescue Timeout::Error
        Rails.logger.warn "Health check timeout, proceeding with basic processing"
        ai_provider = 'basic'  # Fallback to basic processing
      end
      
      # Extract data using Active Storage file
      extraction_result = nil
      
      resume.file.blob.open do |file|
        # Extract structured data with fallback
        extraction_result = ai_service.extract_structured_data(
          file.path, 
          provider: ai_provider
        )
        
        # Check if extraction failed and we got an error
        if extraction_result[:error] && !extraction_result[:data] && !extraction_result['data']
          # Try one more time with basic processing if we haven't already
          if ai_provider != 'basic'
            Rails.logger.info "Retrying with basic processing as fallback"
            extraction_result = ai_service.extract_structured_data(
              file.path, 
              provider: 'basic'
            )
          end
          
          # If still failing, create minimal extracted data to show something
          if extraction_result[:error] && !extraction_result[:data] && !extraction_result['data']
            Rails.logger.warn "All extraction attempts failed, creating basic extraction result"
            extraction_result = create_fallback_extraction(resume)
          end
        end
      end
      
      # Update resume with extracted data (even if partial)
      update_resume_with_extraction(resume, extraction_result)
      
      # Optional enhancement (don't let this block completion)
      if job_description
        Rails.logger.info "Attempting quick enhancement for resume #{resume.id}"
        
        begin
          Timeout::timeout(30) do  # Max 30 seconds for enhancement
            enhancement_result = ai_service.enhance_resume(
              extraction_result,
              job_description.content,
              provider: ai_provider
            )
            
            unless enhancement_result[:error] || enhancement_result['skipped']
              update_resume_with_enhancement(resume, enhancement_result, job_description)
            end
          end
        rescue Timeout::Error
          Rails.logger.warn "Enhancement timeout, skipping for faster completion"
        rescue => enhancement_error
          Rails.logger.warn "Enhancement failed, continuing: #{enhancement_error.message}"
        end
      end
      
      # Mark as completed
      processing_time = Time.current - start_time
      resume.update!(
        processing_status: 'completed',
        processing_completed_at: Time.current,
        ai_provider_used: extraction_result['provider_used'] || ai_provider,
        status: 'processed'  # Also update the main status
      )
      
      Rails.logger.info "✅ Successfully processed resume #{resume.id} in #{processing_time.round(2)}s"
      
      # Broadcast success to user
      broadcast_processing_complete(resume, 'completed', processing_time)
      
    rescue => error
      processing_time = Time.current - start_time
      Rails.logger.error "❌ Resume processing failed for #{resume.id} after #{processing_time.round(2)}s: #{error.message}"
      
      resume.update!(
        processing_status: 'failed',
        processing_error: error.message,
        processing_completed_at: Time.current,
        status: 'failed'
      )
      
      # Broadcast failure to user  
      broadcast_processing_complete(resume, 'failed', processing_time, error.message)
      
      # Don't re-raise - let it fail gracefully
    end
  end

  private

  # Create basic extraction when AI fails completely
  def create_fallback_extraction(resume)
    Rails.logger.info "Creating fallback extraction for resume #{resume.id}"
    
    {
      'data' => {
        'personal_info' => {
          'name' => resume.title || 'Unknown',
          'email' => nil,
          'phone' => nil,
          'location' => nil
        },
        'summary' => 'Unable to extract summary - please review manually',
        'skills' => [],
        'experience' => [],
        'education' => [],
        'raw_text' => 'Text extraction failed'
      },
      'provider_used' => 'fallback',
      'confidence_score' => 0.1,
      'text' => 'Extraction failed - manual review needed'
    }
  end

  # Broadcast processing completion to user
  def broadcast_processing_complete(resume, status, processing_time, error = nil)
    begin
      ActionCable.server.broadcast(
        "user_#{resume.user_id}_resumes",
        {
          type: status == 'completed' ? 'resume_processed' : 'resume_processing_failed',
          resume_id: resume.id,
          status: status,
          processing_time: processing_time.round(2),
          error: error
        }
      )
    rescue => broadcast_error
      Rails.logger.warn "Failed to broadcast completion: #{broadcast_error.message}"
    end
  end
  
  private
  
  def update_resume_with_extraction(resume, extraction_result)
    # Handle the actual AI service response format
    structured_data = extraction_result['structured_data'] || extraction_result['data'] || extraction_result
    
    # Parse the JSON from ai_response if structured fields are empty
    parsed_ai_data = {}
    if structured_data['ai_response'].present?
      begin
        # Extract JSON from markdown code blocks
        json_match = structured_data['ai_response'].match(/```(?:json)?\s*(\{.*?\})\s*```/m)
        if json_match
          parsed_ai_data = JSON.parse(json_match[1])
          Rails.logger.info "📊 Parsed AI response JSON successfully"
        end
      rescue JSON::ParserError => e
        Rails.logger.warn "Failed to parse AI response JSON: #{e.message}"
      end
    end
    
    # Use parsed AI data or fallback to structured fields
    contact_info = parsed_ai_data['contact_info'] || structured_data['contact_info'] || {}
    
    # Clean email (remove encoding issues)
    email = contact_info['email']
    if email && email.match(/[^\w@.-]/)
      email = email.gsub(/[^\w@.-]/, '') # Remove non-standard characters
      email = email.gsub(/^[^a-zA-Z0-9]+/, '') # Remove leading non-alphanumeric
    end
    
    # Parse skills from AI response or structured data
    skills = parsed_ai_data['skills'] || structured_data['skills'] || []
    individual_skills = []
    
    if skills.is_a?(Array)
      skills.each do |skill_group|
        if skill_group.is_a?(String)
          if skill_group.include?(':')
            # Split by colon and take the second part, then split by comma
            skill_items = skill_group.split(':', 2)[1]&.split(',')&.map(&:strip) || []
            individual_skills.concat(skill_items.reject(&:empty?))
          else
            individual_skills << skill_group.strip
          end
        else
          individual_skills << skill_group.to_s
        end
      end
    end
    
    # Parse experience
    experience = parsed_ai_data['experience'] || structured_data['experience'] || []
    
    # Parse education
    education = parsed_ai_data['education'] || structured_data['education'] || []
    
    # Get summary
    summary = parsed_ai_data['summary'] || structured_data['summary']
    summary = 'Professional summary not extracted' if summary.nil? || summary.blank?
    
    # Build update attributes with proper data mapping
    update_attrs = {
      # Basic Information from AI response
      extracted_name: contact_info['name'] || resume.title || 'Unknown Name',
      extracted_email: email,
      extracted_phone: contact_info['phone'],
      extracted_location: contact_info['location'],
      
      # Professional Summary
      extracted_summary: summary,
      
      # Skills (store as JSON)
      extracted_skills: individual_skills.to_json,
      
      # Experience (store as JSON)
      extracted_experience: experience.to_json,
      
      # Education (store as JSON)  
      extracted_education: education.to_json,
      
      # Raw extracted text from AI service
      extracted_text: extraction_result['original_text'] || 
                     extraction_result['text'] || 
                     'Text extraction completed',
      
      # AI confidence scores with fallback
      extraction_confidence: structured_data['confidence_score'] || 0.8,
      
      # Provider tracking
      ai_provider_used: extraction_result['ai_provider'] || extraction_result['provider_used'] || 'ollama'
    }
    
    Rails.logger.info "📝 Updating resume #{resume.id} with AI extracted data"
    Rails.logger.debug "Extracted: Name=#{update_attrs[:extracted_name]}, Email=#{update_attrs[:extracted_email]}, Skills=#{individual_skills.length}, Experience=#{experience.length}"
    
    resume.update!(update_attrs)
  end
  
  def update_resume_with_enhancement(resume, enhancement_result, job_description)
    enhanced_data = enhancement_result['enhanced_resume'] || enhancement_result
    
    # Create or update resume enhancement record
    enhancement = resume.resume_enhancements.find_or_create_by(
      job_description: job_description
    )
    
    enhancement.update!(
      enhanced_summary: enhanced_data['enhanced_summary'],
      enhanced_skills: enhanced_data['enhanced_skills']&.to_json,
      enhanced_experience: enhanced_data['enhanced_experience']&.to_json,
      keyword_matches: enhanced_data['keyword_matches']&.to_json,
      match_score: enhanced_data['match_score'],
      recommendations: enhanced_data['recommendations']&.to_json,
      ai_provider_used: enhancement_result['provider_used']
    )
    
    Rails.logger.info "Enhanced resume #{resume.id} with match score: #{enhanced_data['match_score']}"
  end
end
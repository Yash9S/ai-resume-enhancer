class ProcessResumeJob < ApplicationJob
  queue_as :default
  
  # Allow retries for transient failures only
  retry_on Net::ReadTimeout, Net::OpenTimeout, attempts: 2, wait: 5.seconds
  discard_on ActiveRecord::RecordNotFound
  
  def perform(resume_id, job_description_id = nil, user_id = nil)
    start_time = Time.current
    
    # Find resume and user
    resume = Resume.find(resume_id)
    job_description = job_description_id ? JobDescription.find(job_description_id) : nil
    user = user_id ? User.find(user_id) : resume.user
    
    Rails.logger.info "🚀 Processing resume #{resume.id} for user #{user.id}"
    
    # Update status immediately
    resume.update!(
      processing_status: 'processing',
      processing_started_at: start_time
    )
    
    # Create processing record for tracking
    processing = ResumeProcessing.create!(
      resume: resume,
      job_description: job_description,
      user: user,
      processing_type: job_description ? :matching : :extraction,
      status: :processing,
      started_at: start_time
    )

    begin
      # Try AI microservice first, fallback to Rails service
      extraction_result = extract_with_fallback(resume)
      
      # Update resume with extracted data
      update_resume_with_data(resume, extraction_result)
      
      # Handle job description matching if provided
      if job_description
        matching_result = perform_job_matching(resume, job_description, extraction_result)
        update_processing_with_matching(processing, matching_result)
      end
      
      # Mark as completed
      processing_time = Time.current - start_time
      resume.update!(
        processing_status: 'completed',
        processing_completed_at: Time.current,
        status: 'processed'
      )
      
      processing.update!(
        status: :completed,
        completed_at: Time.current
      )
      
      Rails.logger.info "✅ Resume #{resume.id} processed successfully in #{processing_time.round(2)}s"
      
      # Broadcast success
      broadcast_completion(resume, 'completed', processing_time)
      
    rescue => error
      handle_processing_error(resume, processing, error, start_time)
    end
  end

  private

  def extract_with_fallback(resume)
    Rails.logger.info "🔍 Starting extraction for resume #{resume.id}"
    
    # Strategy 1: Try AI microservice (fast, advanced)
    begin
      ai_service = AiExtractionService.new
      health = ai_service.health_check
      
      if health && health['status'] == 'healthy'
        Rails.logger.info "Using AI microservice for extraction"
        
        resume.file.blob.open do |file|
          result = ai_service.extract_structured_data(file.path, provider: 'basic')
          
          # Check if extraction was successful
          if !result[:error] && result['structured_data']
            Rails.logger.info "✅ AI microservice extraction successful"
            return {
              method: 'microservice',
              data: result['structured_data'],
              provider: result['provider_used'] || 'basic',
              original_text: result['original_text'] || result['text']
            }
          else
            Rails.logger.warn "AI microservice extraction failed: #{result[:error]}"
          end
        end
      else
        Rails.logger.warn "AI microservice not healthy, skipping"
      end
    rescue => e
      Rails.logger.warn "AI microservice error: #{e.message}"
    end
    
    # Strategy 2: Fallback to Rails-based parsing (reliable)
    Rails.logger.info "Using Rails parsing service as fallback"
    
    begin
      parsing_service = ResumeParsingService.new(resume)
      result = parsing_service.extract_content
      
      if result[:error]
        Rails.logger.error "Rails parsing also failed: #{result[:error]}"
        return create_minimal_extraction(resume)
      end
      
      Rails.logger.info "✅ Rails parsing service successful"
      return {
        method: 'rails_service',
        data: result[:extracted_data],
        provider: result[:extraction_method] || 'basic',
        original_text: result[:original_text],
        summary: result[:summary]
      }
      
    rescue => e
      Rails.logger.error "Rails parsing service failed: #{e.message}"
      return create_minimal_extraction(resume)
    end
  end

  def create_minimal_extraction(resume)
    Rails.logger.info "Creating minimal extraction for resume #{resume.id}"
    
    {
      method: 'minimal',
      data: {
        'personal_info' => {
          'name' => resume.title || 'Unknown',
          'email' => nil,
          'phone' => nil
        },
        'summary' => 'Resume uploaded successfully - manual review recommended',
        'skills' => [],
        'experience' => [],
        'education' => []
      },
      provider: 'fallback',
      original_text: 'Text extraction failed - file may be image-based or corrupted'
    }
  end

  def update_resume_with_data(resume, extraction_result)
    data = extraction_result[:data]
    
    # Handle different data structures from different extraction methods
    personal_info = data['personal_info'] || data['contact_info'] || {}
    skills = data['skills'] || []
    experience = data['experience'] || []
    education = data['education'] || []
    summary = extraction_result[:summary] || data['summary'] || 'Professional summary not available'
    
    # Clean and prepare skills array
    skills_array = []
    if skills.is_a?(Array)
      skills.each do |skill|
        if skill.is_a?(String)
          # Handle skills that might be formatted as "Category: skill1, skill2"
          if skill.include?(':')
            skill_parts = skill.split(':', 2)[1]&.split(',')&.map(&:strip) || []
            skills_array.concat(skill_parts.reject(&:blank?))
          else
            skills_array << skill.strip unless skill.blank?
          end
        end
      end
    end
    
    update_attrs = {
      # Personal Information
      extracted_name: personal_info['name'] || resume.title || 'Unknown Name',
      extracted_email: clean_email(personal_info['email']),
      extracted_phone: personal_info['phone'],
      extracted_location: personal_info['location'],
      
      # Professional Summary
      extracted_summary: summary,
      
      # Structured Data (as JSON)
      extracted_skills: skills_array.to_json,
      extracted_experience: experience.to_json,
      extracted_education: education.to_json,
      
      # Raw Text
      extracted_text: extraction_result[:original_text] || 'Text extraction completed',
      
      # Metadata
      extraction_confidence: calculate_confidence(extraction_result),
      ai_provider_used: extraction_result[:provider] || 'unknown'
    }
    
    Rails.logger.info "📝 Updating resume #{resume.id} - Name: #{update_attrs[:extracted_name]}, Skills: #{skills_array.length}"
    
    resume.update!(update_attrs)
  end

  def clean_email(email)
    return nil unless email.present?
    
    # Remove any non-standard characters that might have been OCR'd incorrectly
    email = email.to_s.gsub(/[^\w@.-]/, '')
    
    # Basic email validation
    email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i) ? email : nil
  end

  def calculate_confidence(extraction_result)
    case extraction_result[:method]
    when 'microservice'
      0.9
    when 'rails_service'
      extraction_result[:provider] == 'ollama' ? 0.8 : 0.6
    when 'minimal'
      0.1
    else
      0.5
    end
  end

  def perform_job_matching(resume, job_description, extraction_result)
    Rails.logger.info "🎯 Performing job matching for resume #{resume.id}"
    
    begin
      # Use ResumeParsingService for matching calculation
      parsing_service = ResumeParsingService.new(resume)
      match_score = parsing_service.calculate_match_score(job_description)
      
      # Try enhancement if we have good extracted data
      enhancement_result = nil
      if extraction_result[:method] != 'minimal'
        enhancement_result = parsing_service.enhance_content(job_description)
      end
      
      {
        match_score: match_score,
        enhancement: enhancement_result,
        method: 'calculated'
      }
      
    rescue => e
      Rails.logger.error "Job matching failed: #{e.message}"
      {
        match_score: 0,
        enhancement: { error: e.message },
        method: 'failed'
      }
    end
  end

  def update_processing_with_matching(processing, matching_result)
    processing.update!(
      match_score: matching_result[:match_score],
      ai_response: {
        enhancement: matching_result[:enhancement],
        method: matching_result[:method]
      }.to_json,
      result: matching_result[:enhancement]&.dig(:suggestions)&.join("\n")
    )
  end

  def handle_processing_error(resume, processing, error, start_time)
    processing_time = Time.current - start_time
    
    Rails.logger.error "❌ Resume processing failed for #{resume.id}: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    
    resume.update!(
      processing_status: 'failed',
      processing_error: error.message,
      processing_completed_at: Time.current,
      status: 'failed'
    )
    
    processing.update!(
      status: :failed,
      error_message: error.message,
      completed_at: Time.current
    )
    
    broadcast_completion(resume, 'failed', processing_time, error.message)
  end

  def broadcast_completion(resume, status, processing_time, error = nil)
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
    rescue => e
      Rails.logger.warn "Failed to broadcast completion: #{e.message}"
    end
  end
end
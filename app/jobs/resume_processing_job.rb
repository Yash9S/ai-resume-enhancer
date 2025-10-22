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

  def perform(resume_id, job_description_id = nil, ai_provider = 'ollama', tenant_name = nil)
    start_time = Time.current
    
    # Switch to the correct tenant if provided
    if tenant_name.present?
      Apartment::Tenant.switch(tenant_name) do
        process_resume_in_tenant(resume_id, job_description_id, ai_provider, start_time)
      end
    else
      process_resume_in_tenant(resume_id, job_description_id, ai_provider, start_time)
    end
  end

  private

  def process_resume_in_tenant(resume_id, job_description_id, ai_provider, start_time)
    resume = Resume.find(resume_id)
    job_description = job_description_id ? JobDescription.find(job_description_id) : nil
    
    # Update resume status immediately
    resume.update!(
      processing_status: 'processing',
      processing_started_at: start_time
    )
    
    Rails.logger.info "🚀 Starting robust AI processing for resume #{resume.id} with #{ai_provider}"
    
    begin
      # Extract data using multiple strategies with robust fallback
      extraction_result = extract_with_fallback_strategies(resume, ai_provider)
      
      # Update resume with extracted data (always succeeds)
      update_resume_with_extraction(resume, extraction_result)
      
      # Optional enhancement (don't let this block completion)
      if job_description
        Rails.logger.info "Attempting enhancement for resume #{resume.id}"
        
        begin
          enhancement_result = perform_enhancement_with_fallback(resume, job_description, ai_provider)
          update_resume_with_enhancement(resume, enhancement_result, job_description)
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

  # Multi-strategy extraction with robust fallback
  def extract_with_fallback_strategies(resume, ai_provider)
    Rails.logger.info "🔍 Starting multi-strategy extraction for resume #{resume.id}"
    
    # Use pre-extracted text from database to avoid ActiveStorage issues
    pdf_text = resume.raw_text
    
    if pdf_text.blank?
      Rails.logger.error "❌ No pre-extracted text available for resume #{resume.id}"
      Rails.logger.info "Attempting emergency extraction..."
      
      # Emergency extraction as fallback
      begin
        temp_file = Tempfile.new(['resume_processing', '.pdf'], Dir.tmpdir)
        temp_file.binmode
        
        resume.file.blob.open do |blob_io|
          IO.copy_stream(blob_io, temp_file)
        end
        temp_file.flush
        
        require 'pdf-reader'
        reader = PDF::Reader.new(temp_file.path)
        pdf_text = reader.pages.map(&:text).join("\n").strip
        
        # Store for future use
        resume.update_column(:raw_text, pdf_text) if pdf_text.present?
        Rails.logger.info "✅ Emergency extraction successful: #{pdf_text.length} characters"
        
      rescue => e
        Rails.logger.error "Emergency extraction failed: #{e.message}"
        pdf_text = "Unable to extract text from PDF: #{e.message}"
      ensure
        temp_file&.unlink
      end
    else
      Rails.logger.info "✅ Using pre-extracted text: #{pdf_text.length} characters"
    end
    
    # Strategy 1: Try AI processing with pre-extracted text (Ollama)
    if pdf_text.present? && !pdf_text.include?("Unable to extract")
      Rails.logger.info "Strategy 1: Using AI processing with pre-extracted text"
      begin
        parsing_service = ResumeParsingService.new(resume)
        
        # Use Ollama with the pre-extracted text
        if ai_provider == 'ollama' && parsing_service.send(:check_ollama_availability)
          result = parsing_service.send(:parse_with_ollama, pdf_text)
          
          if !result[:error] && result[:extracted_data]
            Rails.logger.info "✅ Ollama processing successful"
            return {
              'structured_data' => result[:extracted_data],
              'original_text' => pdf_text,
              'provider_used' => 'ollama'
            }
          else
            Rails.logger.warn "Ollama processing failed: #{result[:error]}"
          end
        end
      rescue => e
        Rails.logger.warn "Ollama processing error: #{e.message}"
      end
    end
    
    # Strategy 2: Try AI microservice (if available and healthy)
    if pdf_text.present? && !pdf_text.include?("Unable to extract")
      Rails.logger.info "Strategy 2: Attempting AI microservice extraction"
      begin
        ai_service = AiExtractionService.new
        health_status = ai_service.health_check
        
        if health_status && health_status['status'] == 'healthy'
          # Create temporary file for microservice
          temp_file = Tempfile.new(['resume_processing', '.pdf'], Dir.tmpdir)
          begin
            resume.file.blob.open do |blob_io|
              IO.copy_stream(blob_io, temp_file)
            end
            temp_file.flush
            
            result = ai_service.extract_structured_data(temp_file.path, provider: ai_provider)
            
            if !result[:error] && result['structured_data']
              Rails.logger.info "✅ Microservice extraction successful"
              result['original_text'] = pdf_text
              return result
            else
              Rails.logger.warn "Microservice extraction failed: #{result[:error]}"
            end
          ensure
            temp_file&.unlink
          end
        end
      rescue => e
        Rails.logger.warn "Microservice extraction error: #{e.message}"
      end
    end

    # Strategy 3: Use basic parsing with pre-extracted text
    if pdf_text.present? && !pdf_text.include?("Unable to extract")
      Rails.logger.info "Strategy 3: Using basic parsing with pre-extracted text"
      begin
        parsing_service = ResumeParsingService.new(resume)
        result = parsing_service.send(:parse_with_basic_extraction, pdf_text)
        Rails.logger.info "✅ Basic parsing successful"
        return {
          'structured_data' => result[:extracted_data],
          'original_text' => pdf_text,
          'provider_used' => 'basic_extraction'
        }
        
      rescue => e
        Rails.logger.warn "Basic parsing failed: #{e.message}"
      end
    end
    
    # Strategy 4: Create minimal fallback data with available text
    Rails.logger.info "Strategy 4: Creating minimal fallback extraction"
    return create_fallback_extraction(resume, pdf_text)
  end

  def perform_enhancement_with_fallback(resume, job_description, ai_provider)
    # Try AI microservice enhancement
    begin
      ai_service = AiExtractionService.new
      result = ai_service.enhance_resume(
        resume.extracted_data || {},
        job_description.content,
        provider: ai_provider
      )
      
      return result unless result[:error] || result['skipped']
    rescue => e
      Rails.logger.warn "Microservice enhancement error: #{e.message}"
    end
    
    # Fallback to Rails-based enhancement
    begin
      parsing_service = ResumeParsingService.new(resume)
      return parsing_service.enhance_content(job_description)
    rescue => e
      Rails.logger.warn "Rails enhancement error: #{e.message}"
      return { error: e.message }
    end
  end

  private

  # Create basic extraction when AI fails completely
  def create_fallback_extraction(resume, pdf_text = nil)
    Rails.logger.info "Creating fallback extraction for resume #{resume.id}"
    
    # Use available text or fallback message
    available_text = pdf_text.present? ? pdf_text : 'Text extraction failed - no content available'
    
    {
      'structured_data' => {
        'personal_info' => {
          'name' => resume.title || 'Unknown',
          'email' => nil,
          'phone' => nil,
          'location' => nil
        },
        'summary' => pdf_text.present? ? 'Manual review needed - raw text available' : 'Unable to extract summary - please review manually',
        'skills' => [],
        'experience' => [],
        'education' => []
      },
      'original_text' => available_text,
      'provider_used' => 'fallback',
      'confidence_score' => pdf_text.present? ? 0.3 : 0.1
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
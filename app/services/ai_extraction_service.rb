class AiExtractionService
  include HTTParty
  
  # Use the Ruby AI service directly (simple and reliable)
  base_uri ENV.fetch('RUBY_AI_SERVICE_URL', 'http://192.168.65.254:8001')
  
  def initialize
    @options = {
      headers: {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      },
      timeout: 120 # Maximum 2 minutes for any request
    }
  end

  # Check if AI service is available
  def health_check
    response = self.class.get('/health', @options)
    if response.success?
      result = response.parsed_response
      Rails.logger.info "AI Service health: #{result['status']} (#{result['mode']})"
      result
    else
      Rails.logger.error "AI Service health check failed: HTTP #{response.code}"
      nil
    end
  rescue => e
    Rails.logger.error "AI Service health check failed: #{e.message}"
    nil
  end

  # Get available AI providers (Ollama + Basic)
  def available_providers
    response = self.class.get('/ai-providers', @options)
    if response.success?
      result = response.parsed_response
      Rails.logger.info "Available AI providers: #{result['providers'].keys.join(', ')}"
      result
    else
      Rails.logger.error "Failed to get AI providers: HTTP #{response.code}"
      # Return fallback providers
      {
        'providers' => {
          'basic' => { 'available' => true, 'status' => 'ready', 'cost' => 'free' }
        },
        'recommended' => 'basic'
      }
    end
  rescue => e
    Rails.logger.error "Failed to get AI providers: #{e.message}"
    # Return fallback providers
    {
      'providers' => {
        'basic' => { 'available' => true, 'status' => 'ready', 'cost' => 'free' }
      },
      'recommended' => 'basic'
    }
  end

  # Extract text from resume file
  def extract_text(file_path)
    File.open(file_path, 'rb') do |file|
      response = self.class.post('/extract/text', {
        body: { file: file },
        timeout: 60
      })
      
      if response.success?
        response.parsed_response
      else
        Rails.logger.error "Text extraction failed: #{response.body}"
        { error: "Text extraction failed", details: response.body }
      end
    end
  rescue => e
    Rails.logger.error "Text extraction error: #{e.message}"
    { error: e.message }
  end

  # Extract structured data from resume using Ollama (with basic fallback)
  def extract_structured_data(file_path, provider: 'ollama')
    start_time = Time.current
    
    # Try primary provider first
    result = try_extraction_with_provider(file_path, provider)
    
    # If primary provider fails or takes too long, fallback to basic
    if result[:error] && provider != 'basic'
      Rails.logger.warn "Primary provider #{provider} failed, falling back to basic processing"
      result = try_extraction_with_provider(file_path, 'basic')
    end
    
    processing_time = Time.current - start_time
    Rails.logger.info "Total processing time: #{processing_time.round(2)}s"
    
    result
  end

  private

  def try_extraction_with_provider(file_path, provider)
    timeout = provider == 'ollama' ? 90 : 30  # Shorter timeouts
    
    File.open(file_path, 'rb') do |file|
      response = self.class.post('/extract/structured', {
        body: { 
          file: file,
          provider: provider
        },
        timeout: timeout
      })
      
      if response.success?
        result = response.parsed_response
        Rails.logger.info "Structured extraction completed with #{result['provider_used']} in #{provider} mode"
        result
      else
        Rails.logger.error "Structured extraction failed with #{provider}: HTTP #{response.code}"
        { 
          error: "Extraction failed with #{provider}",
          details: response.body,
          provider_tried: provider
        }
      end
    end
  rescue Net::ReadTimeout, Net::OpenTimeout => e
    Rails.logger.error "Timeout with #{provider} provider: #{e.message}"
    { 
      error: "Timeout with #{provider} provider",
      timeout: true,
      provider_tried: provider
    }
  rescue => e
    Rails.logger.error "Extraction error with #{provider}: #{e.message}"
    { 
      error: e.message,
      provider_tried: provider
    }
  end

  public

  # Enhance resume content against job description using Ollama
  def enhance_resume(resume_data, job_description, provider: 'ollama')
    timeout = provider == 'ollama' ? 60 : 30  # Shorter timeouts for enhancement
    
    response = self.class.post('/enhance', {
      body: {
        resume_data: resume_data,
        job_description: job_description,
        provider: provider
      }.to_json,
      **@options,
      timeout: timeout
    })
    
    if response.success?
      result = response.parsed_response
      Rails.logger.info "Resume enhancement completed with #{result['provider_used']}"
      result
    else
      Rails.logger.error "Resume enhancement failed: HTTP #{response.code} - #{response.body}"
      # Don't fail the entire job if enhancement fails
      { 
        error: "Resume enhancement failed", 
        details: response.body,
        provider_used: provider,
        skipped: true
      }
    end
  rescue Net::ReadTimeout, Net::OpenTimeout => e
    Rails.logger.warn "Enhancement timeout with #{provider}, skipping: #{e.message}"
    { 
      error: "Enhancement timeout",
      provider_used: provider,
      skipped: true
    }
  rescue => e
    Rails.logger.warn "Enhancement error with #{provider}, skipping: #{e.message}"
    { 
      error: e.message,
      provider_used: provider,
      skipped: true
    }
  end

  # Process resume asynchronously (if AI service supports it)
  def process_async(file_path, job_description = nil, provider: 'ollama')
    File.open(file_path, 'rb') do |file|
      response = self.class.post('/process/async', {
        body: { 
          file: file,
          job_description: job_description,
          provider: provider
        },
        timeout: 30
      })
      
      if response.success?
        response.parsed_response # Should return job_id for tracking
      else
        Rails.logger.error "Async processing failed: #{response.body}"
        { error: "Async processing failed", details: response.body }
      end
    end
  rescue => e
    Rails.logger.error "Async processing error: #{e.message}"
    { error: e.message }
  end

  # Check async job status
  def job_status(job_id)
    response = self.class.get("/job/#{job_id}/status", @options)
    response.success? ? response.parsed_response : nil
  rescue => e
    Rails.logger.error "Job status check failed: #{e.message}"
    nil
  end

  private

  def handle_file_upload(file_path)
    # Ensure file exists and is readable
    unless File.exist?(file_path) && File.readable?(file_path)
      raise "File not found or not readable: #{file_path}"
    end
    
    # Check file size (limit to 10MB)
    if File.size(file_path) > 10.megabytes
      raise "File too large. Maximum size is 10MB"
    end
    
    file_path
  end
end
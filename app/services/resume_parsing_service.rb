class ResumeParsingService
  include HTTParty
  
  # You can switch between different AI services
  # Set OPENAI_API_KEY or HUGGINGFACE_API_KEY in environment variables
  # Or set OLLAMA_BASE_URL for local Ollama instance (100% FREE!)
  
  OPENAI_BASE_URL = 'https://api.openai.com/v1/chat/completions'
  HUGGINGFACE_BASE_URL = 'https://api-inference.huggingface.co/models'
  OLLAMA_BASE_URL = ENV['OLLAMA_BASE_URL'] || 'http://localhost:11434'

  def initialize(resume)
    @resume = resume
    @api_key = Rails.application.credentials.openai_api_key || ENV['OPENAI_API_KEY']
    @hf_api_key = Rails.application.credentials.huggingface_api_key || ENV['HUGGINGFACE_API_KEY']
    @ollama_enabled = check_ollama_availability
  end

  def extract_content
    return { error: 'No file attached' } unless @resume.file.attached?

    # Extract text content from PDF or DOCX
    text_content = extract_text_from_file

    # Priority: 1. Ollama (free local), 2. Hugging Face (free), 3. OpenAI (paid), 4. Basic
    if @ollama_enabled
      parse_with_ollama(text_content)
    elsif @hf_api_key.present?
      parse_with_huggingface(text_content)
    elsif @api_key.present?
      parse_with_openai(text_content)
    else
      parse_with_basic_extraction(text_content)
    end
  end

  def enhance_content(job_description = nil)
    # If resume content is not available due to extraction failure, try basic enhancement
    unless @resume.extracted_content.present?
      if @resume.original_content.present?
        # Use original content as fallback
        content = @resume.original_content
      else
        return { 
          error: 'No content available for enhancement',
          enhanced_content: 'Resume content could not be extracted. Please try uploading a different file or enter your resume content manually.',
          suggestions: [
            'Upload a text-based PDF (not scanned)',
            'Try uploading a Word document (.docx)',
            'Manually enter your resume content using the editor'
          ]
        }
      end
    else
      content = @resume.extracted_content
    end

    prompt = build_enhancement_prompt(content, job_description)
    
    begin
      if @ollama_enabled
        result = enhance_with_ollama(prompt)
      elsif @hf_api_key.present?
        result = enhance_with_huggingface(prompt)
      elsif @api_key.present?
        result = enhance_with_openai(prompt)
      else
        result = basic_enhancement(content)
      end
      
      # Ensure we always return a valid structure
      result[:enhanced_content] ||= content
      result[:suggestions] ||= ['Content enhancement completed']
      result
      
    rescue => e
      Rails.logger.error "Enhancement failed: #{e.message}"
      basic_enhancement(content)
    end
  end

  def calculate_match_score(job_description)
    # Fallback to basic text analysis if extracted_data is not available
    unless @resume.extracted_data.present?
      # Try to calculate score based on available content
      content = @resume.extracted_content || @resume.original_content || ''
      return calculate_basic_match_score(content, job_description) if content.present?
      return 0
    end

    resume_skills = extract_skills_from_data(@resume.extracted_data)
    jd_keywords = job_description.keywords

    return 0 if resume_skills.empty? || jd_keywords.empty?

    matches = resume_skills.select { |skill| jd_keywords.any? { |keyword| keyword.include?(skill.downcase) } }
    (matches.length.to_f / jd_keywords.length * 100).round(2)
  end

  def calculate_basic_match_score(content, job_description)
    return 0 unless content.present? && job_description.content.present?
    
    # Simple keyword matching
    content_words = content.downcase.split(/\W+/)
    jd_words = job_description.content.downcase.split(/\W+/).uniq
    
    # Filter out common words
    common_words = %w[the and or but for with from to of in on at by]
    meaningful_jd_words = jd_words - common_words
    
    return 0 if meaningful_jd_words.empty?
    
    matches = meaningful_jd_words.count { |word| content_words.include?(word) }
    (matches.to_f / meaningful_jd_words.length * 100).round(2)
  end

  private

  def extract_text_from_file
    case @resume.file.content_type
    when 'application/pdf'
      extract_from_pdf
    when 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      extract_from_docx
    else
      'Unsupported file format'
    end
  end

  def extract_from_pdf
    begin
      require 'pdf-reader'
      
      # Try different methods to access the file content
      if @resume.file.attached?
        # Method 1: Try to open directly from Active Storage
        begin
          @resume.file.open do |file|
            reader = PDF::Reader.new(file)
            text = reader.pages.map(&:text).join("\n")
            return text.present? ? text : 'Unable to extract text from PDF'
          end
        rescue => e
          Rails.logger.error "PDF extraction method 1 failed: #{e.message}"
          
          # Method 2: Try downloading to temporary file with proper path handling
          begin
            temp_file = Tempfile.new(['resume', '.pdf'])
            temp_file.binmode
            
            # Use the blob directly
            @resume.file.blob.open do |blob_file|
              temp_file.write(blob_file.read)
            end
            temp_file.rewind
            
            reader = PDF::Reader.new(temp_file.path)
            text = reader.pages.map(&:text).join("\n")
            temp_file.close
            temp_file.unlink
            
            return text.present? ? text : 'Unable to extract text from PDF'
          rescue => e
            Rails.logger.error "PDF extraction method 2 failed: #{e.message}"
            
            # Method 3: Try using ActiveStorage download
            begin
              pdf_data = @resume.file.download
              temp_file = Tempfile.new(['resume', '.pdf'])
              temp_file.binmode
              temp_file.write(pdf_data)
              temp_file.rewind
              
              reader = PDF::Reader.new(temp_file.path)
              text = reader.pages.map(&:text).join("\n")
              temp_file.close
              temp_file.unlink
              
              return text.present? ? text : 'Unable to extract text from PDF - file may be image-based'
            rescue => e
              Rails.logger.error "PDF extraction method 3 failed: #{e.message}"
              return 'PDF extraction failed - please try uploading a text-based PDF file'
            end
          end
        end
      else
        return 'No file attached'
      end
    rescue => e
      Rails.logger.error "PDF extraction error: #{e.class}: #{e.message}"
      'Error extracting text from PDF - please ensure the file is a valid PDF'
    end
  end

  def extract_from_docx
    # Basic DOCX text extraction - you might want to use a gem like docx or rubyzip
    begin
      # This is a simplified version - in production, use proper DOCX parsing
      'DOCX content extraction not implemented - please use PDF format'
    rescue => e
      Rails.logger.error "DOCX extraction error: #{e.message}"
      'Error extracting text from DOCX'
    end
  end

  def parse_with_openai(text_content)
    prompt = build_extraction_prompt(text_content)
    
    response = HTTParty.post(
      OPENAI_BASE_URL,
      headers: {
        'Authorization' => "Bearer #{@api_key}",
        'Content-Type' => 'application/json'
      },
      body: {
        model: 'gpt-3.5-turbo',
        messages: [
          {
            role: 'system',
            content: 'You are an expert resume parser. Extract structured information from resumes and return it as JSON.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        max_tokens: 1500,
        temperature: 0.1
      }.to_json
    )

    if response.success?
      content = response.dig('choices', 0, 'message', 'content')
      parse_ai_response(content)
    else
      error_message = response.dig('error', 'message') || response.message
      
      # Handle specific API errors gracefully
      if response.code == 429 || error_message.include?('rate limit') || error_message.include?('Too Many Requests')
        Rails.logger.warn "OpenAI rate limit hit during parsing, falling back to basic extraction"
        return parse_with_basic_extraction(text_content)
      elsif response.code == 401
        Rails.logger.error "OpenAI API authentication failed"
        return { error: "API authentication failed" }
      else
        Rails.logger.error "OpenAI API parsing error: #{error_message}"
        return parse_with_basic_extraction(text_content)
      end
    end
  rescue => e
    Rails.logger.error "OpenAI parsing error: #{e.message}"
    parse_with_basic_extraction(text_content)
  rescue => e
    Rails.logger.error "OpenAI API error: #{e.message}"
    { error: "Failed to parse with OpenAI: #{e.message}" }
  end

  def parse_with_huggingface(text_content)
    # Using a free text processing model on Hugging Face
    model_name = 'facebook/bart-large-cnn' # For summarization
    
    response = HTTParty.post(
      "#{HUGGINGFACE_BASE_URL}/#{model_name}",
      headers: {
        'Authorization' => "Bearer #{@hf_api_key}",
        'Content-Type' => 'application/json'
      },
      body: {
        inputs: text_content.truncate(1000), # Limit input size
        parameters: {
          max_length: 500,
          min_length: 50
        }
      }.to_json
    )

    if response.success?
      summary = response[0]['summary_text']
      basic_extraction_with_summary(text_content, summary)
    else
      { error: "Hugging Face API error: #{response.message}" }
    end
  rescue => e
    Rails.logger.error "Hugging Face API error: #{e.message}"
    parse_with_basic_extraction(text_content)
  end

  def parse_with_ollama(text_content)
    # Using local Ollama for completely free AI processing
    prompt = build_extraction_prompt(text_content)
    
    Rails.logger.info "Using Ollama for resume parsing (local AI)"
    
    response = HTTParty.post(
      "#{OLLAMA_BASE_URL}/api/generate",
      headers: {
        'Content-Type' => 'application/json'
      },
      body: {
        model: 'llama3.2:3b',  # Free local model optimized for text processing
        prompt: prompt,
        stream: false,
        options: {
          temperature: 0.1,      # Lower temperature for more consistent results
          top_p: 0.9,
          num_predict: 800,      # Reduced for faster processing
          num_ctx: 2048          # Reduced context window for speed
        }
      }.to_json,
      timeout: 60  # Reduced timeout for faster fallback
    )

    if response.success?
      content = response.dig('response')
      Rails.logger.info "Ollama processing successful"
      
      # Check if Ollama refused to help or gave an error response
      if content.downcase.include?("i can't help") || content.downcase.include?("cannot help") || content.length < 50
        Rails.logger.warn "Ollama refused to process content, falling back to basic extraction"
        return parse_with_basic_extraction(text_content)
      end
      
      # Try to parse as JSON, fallback to text processing
      begin
        parsed_response = JSON.parse(content)
        return parse_ai_response(content)
      rescue JSON::ParserError
        # If not JSON, extract information manually
        return parse_ollama_text_response(content, text_content)
      end
    else
      Rails.logger.warn "Ollama not available (#{response.code}), falling back to basic extraction"
      parse_with_basic_extraction(text_content)
    end
  rescue => e
    Rails.logger.error "Ollama error: #{e.message}"
    Rails.logger.info "Falling back to basic text processing"
    parse_with_basic_extraction(text_content)
  end

  def parse_ollama_text_response(ai_response, original_text)
    # Parse Ollama's text response into structured data
    {
      original_text: original_text,
      summary: ai_response.truncate(500),
      extracted_data: extract_basic_info_from_text(ai_response, original_text),
      extraction_method: 'ollama_local'
    }
  end

  def extract_basic_info_from_text(ai_response, original_text)
    # Extract information from AI response or original text
    combined_text = "#{ai_response}\n#{original_text}"
    
    {
      contact_info: extract_contact_info(combined_text),
      skills: extract_skills_basic(combined_text),
      education: extract_education_basic(combined_text),
      experience: extract_experience_basic(combined_text),
      summary: ai_response.split("\n").first(3).join(" ").truncate(200)
    }
  end

  def check_ollama_availability
    return false unless OLLAMA_BASE_URL.present?
    
    begin
      response = HTTParty.get("#{OLLAMA_BASE_URL}/api/tags", timeout: 5)
      response.success?
    rescue
      false
    end
  end

  def parse_with_basic_extraction(text_content)
    # Handle failed PDF extraction cases
    if text_content.include?('Error') || text_content.include?('Unable to extract') || text_content.include?('temporarily unavailable')
      return {
        original_text: text_content,
        extracted_data: {
          contact_info: { error: 'PDF extraction failed' },
          skills: [],
          education: [],
          experience: [],
          summary: build_extraction_failure_message(text_content)
        },
        extraction_method: 'failed'
      }
    end
    
    {
      original_text: text_content,
      extracted_data: {
        contact_info: extract_contact_info(text_content),
        skills: extract_skills_basic(text_content),
        education: extract_education_basic(text_content),
        experience: extract_experience_basic(text_content),
        summary: text_content.split("\n").first(3).join(" ").truncate(200)
      },
      extraction_method: 'basic'
    }
  end

  def build_extraction_failure_message(error_text)
    case error_text
    when /temporarily unavailable/
      "PDF processing is temporarily unavailable. This might be due to the file being too large or complex. Please try again in a few minutes or try uploading a simpler PDF."
    when /Unable to extract/
      "Unable to extract text from this PDF. The file might be image-based (scanned) rather than text-based. Try using a different PDF or upload a Word document (.docx) instead."
    when /Error/
      "An error occurred while processing your PDF file. Please check that the file is not corrupted and try uploading again."
    else
      "PDF processing failed. Please try uploading a different file or contact support if the problem persists."
    end
  end

  def build_extraction_prompt(text_content)
    <<~PROMPT
      You are a resume parser. Extract key information from the following resume text and provide a structured summary.

      Please extract and organize:
      - Name and contact information
      - Professional summary or objective
      - Work experience with companies and roles
      - Education background
      - Technical skills
      - Certifications (if any)

      Format the response as readable text, not JSON. Focus on the most important information.

      Resume text to analyze:
      #{text_content.truncate(2000)}

      Provide a clear, organized summary of this person's background and qualifications.
    PROMPT
  end

  def build_enhancement_prompt(content, job_description)
    jd_text = job_description&.content || "General professional position"
    
    <<~PROMPT
      You are helping to improve a resume. Please review the following resume content and suggest improvements.

      Current resume content:
      #{content.truncate(1000)}
      
      Target job type:
      #{jd_text.truncate(500)}
      
      Please provide 3-5 specific suggestions to make this resume more effective:
      - Ways to better highlight relevant experience
      - Skills that should be emphasized
      - Improvements to professional summary
      - Better formatting or organization ideas
      
      Focus on practical, actionable advice.
    PROMPT
  end

  def enhance_with_openai(prompt)
    response = HTTParty.post(
      OPENAI_BASE_URL,
      headers: {
        'Authorization' => "Bearer #{@api_key}",
        'Content-Type' => 'application/json'
      },
      body: {
        model: 'gpt-3.5-turbo',
        messages: [
          {
            role: 'system',
            content: 'You are a professional resume writer. Help enhance resumes for specific job applications.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        max_tokens: 2000,
        temperature: 0.3
      }.to_json
    )

    if response.success?
      content = response.dig('choices', 0, 'message', 'content')
      parse_enhancement_response(content)
    else
      error_message = response.dig('error', 'message') || response.message
      
      # Handle specific API errors
      if response.code == 429 || error_message.include?('rate limit') || error_message.include?('Too Many Requests')
        Rails.logger.warn "OpenAI rate limit hit, falling back to basic enhancement"
        return basic_enhancement(@resume.extracted_content || @resume.original_content || '')
      elsif response.code == 401
        Rails.logger.error "OpenAI API authentication failed"
        return { error: "API authentication failed" }
      else
        Rails.logger.error "OpenAI API error: #{error_message}"
        return basic_enhancement(@resume.extracted_content || @resume.original_content || '')
      end
    end
  rescue => e
    Rails.logger.error "OpenAI enhancement error: #{e.message}"
    basic_enhancement(@resume.extracted_content || @resume.original_content || '')
  end

  def enhance_with_ollama(prompt)
    Rails.logger.info "Using Ollama for content enhancement"
    
    response = HTTParty.post(
      "#{OLLAMA_BASE_URL}/api/generate",
      headers: {
        'Content-Type' => 'application/json'
      },
      body: {
        model: 'llama3.2:3b',
        prompt: prompt,
        stream: false,
        options: {
          temperature: 0.3,    # Slightly higher for creative suggestions
          top_p: 0.9,
          num_predict: 800
        }
      }.to_json,
      timeout: 120
    )

    if response.success?
      ai_suggestions = response.dig('response')
      
      {
        enhanced_content: @resume.extracted_content,
        suggestions: parse_ollama_suggestions(ai_suggestions),
        enhancement_method: 'ollama_local'
      }
    else
      Rails.logger.warn "Ollama enhancement failed, using basic enhancement"
      basic_enhancement(@resume.extracted_content)
    end
  rescue => e
    Rails.logger.error "Ollama enhancement error: #{e.message}"
    basic_enhancement(@resume.extracted_content)
  end

  def parse_ollama_suggestions(ai_response)
    # Extract actionable suggestions from Ollama's response
    suggestions = []
    
    # Look for bullet points or numbered lists
    ai_response.split(/\n/).each do |line|
      cleaned_line = line.strip
      if cleaned_line.match(/^[-*•]\s*(.+)/) || cleaned_line.match(/^\d+\.\s*(.+)/)
        suggestion = $1 || cleaned_line
        suggestions << suggestion if suggestion.length > 10
      elsif cleaned_line.length > 20 && cleaned_line.include?('suggest') || cleaned_line.include?('improve')
        suggestions << cleaned_line
      end
    end
    
    # Fallback to basic suggestions if AI didn't provide clear ones
    if suggestions.empty?
      suggestions = [
        "Consider the AI's feedback: #{ai_response.truncate(100)}",
        "Review and refine based on the suggestions above",
        "Add more quantifiable achievements with numbers"
      ]
    end
    
    suggestions.first(5) # Limit to 5 suggestions
  end

  def enhance_with_huggingface(prompt)
    # Basic enhancement using available models
    basic_enhancement(@resume.extracted_content)
  end

  def basic_enhancement(content)
    {
      suggestions: [
        "Use more action verbs in experience descriptions",
        "Add quantifiable achievements with numbers/percentages",
        "Include relevant keywords from the job description",
        "Strengthen the professional summary",
        "Highlight technical skills more prominently"
      ],
      enhanced_content: content,
      enhancement_method: 'basic'
    }
  end

  def parse_ai_response(content)
    JSON.parse(content)
  rescue JSON::ParserError
    # If AI returns non-JSON, try to extract useful information
    {
      extracted_data: { raw_ai_response: content },
      extraction_method: 'ai_raw'
    }
  end

  def parse_enhancement_response(content)
    JSON.parse(content)
  rescue JSON::ParserError
    {
      suggestions: [content],
      enhanced_content: @resume.extracted_content
    }
  end

  # Basic text extraction methods
  def extract_contact_info(text)
    email_regex = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/
    phone_regex = /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/
    
    {
      email: text.scan(email_regex).first,
      phone: text.scan(phone_regex).first
    }
  end

  def extract_skills_basic(text)
    # Common technical skills keywords
    tech_skills = %w[
      Python Java JavaScript Ruby Rails React Node.js SQL HTML CSS Git 
      AWS Azure Docker Kubernetes Linux Windows MacOS Excel PowerPoint
      Machine Learning AI Data Analysis Project Management Agile
    ]
    
    found_skills = tech_skills.select { |skill| text.downcase.include?(skill.downcase) }
    found_skills.uniq
  end

  def extract_education_basic(text)
    education_keywords = %w[University College Bachelor Master PhD Degree Education]
    lines = text.split("\n")
    
    education_lines = lines.select do |line|
      education_keywords.any? { |keyword| line.downcase.include?(keyword.downcase) }
    end
    
    education_lines.first(3) # Return up to 3 education entries
  end

  def extract_experience_basic(text)
    # Look for lines that might contain job titles or companies
    experience_keywords = %w[Manager Developer Engineer Analyst Consultant Director]
    lines = text.split("\n")
    
    experience_lines = lines.select do |line|
      experience_keywords.any? { |keyword| line.include?(keyword) } ||
      line.match?(/\d{4}[-–]\d{4}/) || # Date ranges
      line.match?(/\d{4}[-–]Present/i)
    end
    
    experience_lines.first(5) # Return up to 5 experience entries
  end

  def extract_skills_from_data(extracted_data)
    skills = []
    skills += extracted_data['skills'] if extracted_data['skills'].is_a?(Array)
    skills += extracted_data['technical_skills'] if extracted_data['technical_skills'].is_a?(Array)
    skills.flatten.uniq.map(&:downcase)
  end

  def basic_extraction_with_summary(text_content, summary)
    {
      original_text: text_content,
      summary: summary,
      extracted_data: {
        contact_info: extract_contact_info(text_content),
        skills: extract_skills_basic(text_content),
        education: extract_education_basic(text_content),
        experience: extract_experience_basic(text_content),
        ai_summary: summary
      },
      extraction_method: 'huggingface_basic'
    }
  end
end
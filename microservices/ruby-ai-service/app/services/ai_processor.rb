class AiProcessor
  def initialize
    @ollama_client = OllamaClient.new
  end

  def extract_structured_data(text, provider: 'ollama')
    case provider
    when 'ollama'
      extract_with_ollama(text)
    else
      extract_with_basic(text)
    end
  end

  private 

  def extract_with_ollama(text)
    return extract_with_basic(text) unless @ollama_client.available?

    prompt = build_extraction_prompt(text)

    result = @ollama_client.generate(
      model: 'llama3.2',
      prompt: prompt,
      system: "You are an expert resume parser. Extract information accurately and return valid JSON only."
    )

    if result[:success]
      parse_ai_response(result[:content])
    else
      Rails.logger.warn "Ollama extraction failed: #{result[:error]}"
      extract_with_basic(text)
    end
  rescue => e
    Rails.logger.error "AI extraction error: #{e.message}"
    extract_with_basic(text)
  end

  def extract_with_basic(text)
    BasicTextProcessor.new.extract_data(text)
  end

  def build_extraction_prompt(text)
    <<~PROMPT
      Extract structured information from this resume text and return ONLY a JSON object with this exact structure:

      {
        "contact_info": {
          "name": "Full Name",
          "email": "email@example.com",
          "phone": "phone number",
          "location": "city, state/country"
        },
        "summary": "Professional summary or objective",
        "skills": ["skill1", "skill2", "skill3"],
        "experience": [
          {
            "title": "Job Title",
            "company": "Company Name",
            "duration": "Start - End dates",
            "description": "Job description"
          }
        ],
        "education": [
          {
            "degree": "Degree Name",
            "institution": "School Name",
            "year": "Graduation year",
            "details": "Additional details"
          }
        ]
      }

      Resume text:
      #{text}

      Return only the JSON object, no additional text or formatting.
    PROMPT
  end

  def parse_ai_response(content)
    # Try to extract JSON from the response
    json_match = content.match(/\{.*\}/m)
    if json_match
      data = JSON.parse(json_match[0])
      {
        success: true,
        structured_data: data,
        provider_used: 'ollama',
        confidence_score: 0.9,
        original_text: content
      }
    else
      raise "No JSON found in AI response"
    end
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse AI JSON response: #{e.message}"
    BasicTextProcessor.new.extract_data(content)
  end
end
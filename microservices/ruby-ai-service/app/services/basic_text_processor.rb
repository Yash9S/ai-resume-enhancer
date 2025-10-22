class BasicTextProcessor
  def extract_data(text)
    {
      success: true,
      structured_data: {
        contact_info: extract_contact_info(text),
        summary: extract_summary(text),
        skills: extract_skills(text),
        experience: extract_experience(text),
        education: extract_education(text)
      },
      provider_used: 'basic',
      confidence_score: 0.6,
      original_text: text
    }
  end

  private

  def extract_contact_info(text)
    email = text.match(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/)&.[](0)
    phone = text.match(/\b(?:\+?1[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}\b/)&.[](0)
    
    # Simple name extraction (first line or before email)
    lines = text.split("\n").map(&:strip).reject(&:empty?)
    name = lines.first&.length&.< 50 ? lines.first : "Name not found"

    {
      name: name,
      email: email,
      phone: phone,
      location: nil
    }
  end

  def extract_summary(text)
    # Look for summary/objective sections
    summary_match = text.match(/(?:summary|objective|profile)[\s:]+(.{50,300})/i)
    summary_match ? summary_match[1].strip : "Professional summary not found"
  end

  def extract_skills(text)
    # Simple skills extraction
    skills_section = text.match(/(?:skills|technologies|competencies)[\s:]+(.+?)(?:\n\n|\n[A-Z])/mi)
    if skills_section
      skills_section[1].split(/[,\n•\-\*]/).map(&:strip).reject(&:empty?).first(10)
    else
      []
    end
  end

  def extract_experience(text)
    # Basic experience extraction
    [{
      title: "Experience details not fully extracted",
      company: "See original resume",
      duration: "Various",
      description: "Basic extraction - please review original"
    }]
  end

  def extract_education(text)
    # Basic education extraction
    [{
      degree: "Education details not fully extracted", 
      institution: "See original resume",
      year: "Various",
      details: "Basic extraction - please review original"
    }]
  end
end
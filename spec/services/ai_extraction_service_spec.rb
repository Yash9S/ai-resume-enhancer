# spec/services/ai_extraction_service_spec.rb
require 'rails_helper'

RSpec.describe AiExtractionService, type: :service do
  let(:service) { AiExtractionService.new }
  let(:sample_pdf_path) { Rails.root.join('spec', 'fixtures', 'files', 'sample_resume.pdf') }
  
  # Mock AI Service Responses
  let(:successful_ai_response) do
    {
      'job_id' => '1234-5678-9012',
      'success' => true,
      'original_text' => 'John Doe\njohn.doe@email.com\n+1-555-123-4567\nSoftware Engineer with 5 years of experience...',
      'structured_data' => {
        'summary' => 'Experienced software engineer with expertise in Ruby on Rails',
        'contact_info' => {
          'name' => 'John Doe',
          'email' => 'john.doe@email.com',
          'phone' => '+1-555-123-4567',
          'location' => 'San Francisco, CA'
        },
        'skills' => [
          'Languages: Ruby, JavaScript, Python',
          'Frameworks: Rails, React, Django',
          'Databases: PostgreSQL, MongoDB'
        ],
        'experience' => [
          {
            'company' => 'Tech Corp',
            'position' => 'Senior Software Engineer',
            'duration' => 'Jan 2020 - Present',
            'description' => 'Led development of microservices architecture'
          }
        ],
        'education' => [
          {
            'degree' => 'BS Computer Science',
            'institution' => 'University of Technology',
            'year' => '2018'
          }
        ],
        'ai_response' => '```json\n{\n  "contact_info": {\n    "name": "John Doe",\n    "email": "john.doe@email.com",\n    "phone": "+1-555-123-4567",\n    "location": "San Francisco, CA"\n  },\n  "summary": "Experienced software engineer",\n  "skills": ["Ruby", "JavaScript", "Python"],\n  "experience": [{"company": "Tech Corp", "position": "Senior Engineer"}],\n  "education": [{"degree": "BS CS", "institution": "University"}]\n}\n```',
        'provider_used' => 'ollama',
        'extraction_method' => 'ai_text_parsing'
      },
      'file_info' => {
        'filename' => 'sample_resume.pdf',
        'size' => 45123,
        'content_type' => 'application/pdf'
      },
      'ai_provider' => 'ollama',
      'timestamp' => Time.current.iso8601,
      'error' => nil
    }
  end

  let(:failed_ai_response) do
    {
      'success' => false,
      'error' => 'AI service timeout',
      'job_id' => '1234-5678-9013',
      'timestamp' => Time.current.iso8601
    }
  end

  let(:malformed_ai_response) do
    {
      'success' => true,
      'structured_data' => {
        'ai_response' => '```json\n{\n  "contact_info": {\n    "name": "John Doe"\n    "email": "invalid json\n}\n```'
      }
    }
  end

  describe '#health_check' do
    context 'when AI service is available' do
      before do
        stub_request(:get, "#{service.instance_variable_get(:@ai_service_url)}/health")
          .to_return(
            status: 200,
            body: { status: 'healthy', version: '1.0.0' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns true for healthy service' do
        expect(service.health_check).to be true
      end

      it 'makes correct HTTP request' do
        service.health_check
        expect(WebMock).to have_requested(:get, "#{service.instance_variable_get(:@ai_service_url)}/health")
      end
    end

    context 'when AI service is unavailable' do
      before do
        stub_request(:get, "#{service.instance_variable_get(:@ai_service_url)}/health")
          .to_return(status: 500)
      end

      it 'returns false for unhealthy service' do
        expect(service.health_check).to be false
      end
    end

    context 'when AI service times out' do
      before do
        stub_request(:get, "#{service.instance_variable_get(:@ai_service_url)}/health")
          .to_timeout
      end

      it 'returns false on timeout' do
        expect(service.health_check).to be false
      end
    end
  end

  describe '#extract_structured_data' do
    let(:file_path) { sample_pdf_path }

    context 'with successful AI response' do
      before do
        stub_request(:post, "#{service.instance_variable_get(:@ai_service_url)}/extract/structured")
          .with(
            headers: { 'Accept' => 'application/json' },
            body: hash_including('file', 'provider')
          )
          .to_return(
            status: 200,
            body: successful_ai_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'extracts structured data successfully' do
        result = service.extract_structured_data(file_path, provider: 'ollama')
        
        expect(result).to be_a(Hash)
        expect(result['success']).to be true
        expect(result['structured_data']).to be_present
      end

      it 'includes contact information' do
        result = service.extract_structured_data(file_path)
        contact_info = result.dig('structured_data', 'contact_info')
        
        expect(contact_info['name']).to eq('John Doe')
        expect(contact_info['email']).to eq('john.doe@email.com')
        expect(contact_info['phone']).to eq('+1-555-123-4567')
        expect(contact_info['location']).to eq('San Francisco, CA')
      end

      it 'includes skills array' do
        result = service.extract_structured_data(file_path)
        skills = result.dig('structured_data', 'skills')
        
        expect(skills).to be_an(Array)
        expect(skills).to include('Languages: Ruby, JavaScript, Python')
        expect(skills).to include('Frameworks: Rails, React, Django')
      end

      it 'includes experience data' do
        result = service.extract_structured_data(file_path)
        experience = result.dig('structured_data', 'experience')
        
        expect(experience).to be_an(Array)
        expect(experience.first['company']).to eq('Tech Corp')
        expect(experience.first['position']).to eq('Senior Software Engineer')
        expect(experience.first['duration']).to eq('Jan 2020 - Present')
      end

      it 'includes education data' do
        result = service.extract_structured_data(file_path)
        education = result.dig('structured_data', 'education')
        
        expect(education).to be_an(Array)
        expect(education.first['degree']).to eq('BS Computer Science')
        expect(education.first['institution']).to eq('University of Technology')
      end

      it 'tracks provider used' do
        result = service.extract_structured_data(file_path, provider: 'ollama')
        
        expect(result['ai_provider']).to eq('ollama')
        expect(result.dig('structured_data', 'provider_used')).to eq('ollama')
      end

      it 'includes original text' do
        result = service.extract_structured_data(file_path)
        
        expect(result['original_text']).to include('John Doe')
        expect(result['original_text']).to include('john.doe@email.com')
      end

      it 'includes file metadata' do
        result = service.extract_structured_data(file_path)
        file_info = result['file_info']
        
        expect(file_info['content_type']).to eq('application/pdf')
        expect(file_info['size']).to be_a(Integer)
      end
    end

    context 'with failed AI response' do
      before do
        stub_request(:post, "#{service.instance_variable_get(:@ai_service_url)}/extract/structured")
          .to_return(
            status: 500,
            body: failed_ai_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'handles AI service errors gracefully' do
        result = service.extract_structured_data(file_path)
        
        expect(result[:error]).to include('Extraction failed')
        expect(result[:provider_tried]).to eq('ollama')
      end
    end

    context 'with timeout' do
      before do
        stub_request(:post, "#{service.instance_variable_get(:@ai_service_url)}/extract/structured")
          .to_timeout
      end

      it 'handles timeout with fallback' do
        result = service.extract_structured_data(file_path, provider: 'ollama')
        
        expect(result[:error]).to include('timeout')
        expect(result[:timeout]).to be true
      end
    end

    context 'with malformed JSON in AI response' do
      before do
        stub_request(:post, "#{service.instance_variable_get(:@ai_service_url)}/extract/structured")
          .to_return(
            status: 200,
            body: malformed_ai_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'handles malformed JSON gracefully' do
        result = service.extract_structured_data(file_path)
        
        expect(result).to be_a(Hash)
        expect(result['success']).to be true
        # Should still return the response even if AI response JSON is malformed
      end
    end

    context 'with different providers' do
      it 'uses correct endpoint for ollama provider' do
        stub_request(:post, "#{service.instance_variable_get(:@ai_service_url)}/extract/structured")
          .with(body: hash_including('provider' => 'ollama'))
          .to_return(status: 200, body: successful_ai_response.to_json)

        service.extract_structured_data(file_path, provider: 'ollama')
        
        expect(WebMock).to have_requested(:post, "#{service.instance_variable_get(:@ai_service_url)}/extract/structured")
          .with(body: hash_including('provider' => 'ollama'))
      end

      it 'uses correct endpoint for basic provider' do
        stub_request(:post, "#{service.instance_variable_get(:@ai_service_url)}/extract/structured")
          .with(body: hash_including('provider' => 'basic'))
          .to_return(status: 200, body: successful_ai_response.to_json)

        service.extract_structured_data(file_path, provider: 'basic')
        
        expect(WebMock).to have_requested(:post, "#{service.instance_variable_get(:@ai_service_url)}/extract/structured")
          .with(body: hash_including('provider' => 'basic'))
      end
    end

    context 'with fallback provider chain' do
      it 'tries basic provider when ollama fails' do
        # First request to ollama fails
        stub_request(:post, "#{service.instance_variable_get(:@ai_service_url)}/extract/structured")
          .with(body: hash_including('provider' => 'ollama'))
          .to_return(status: 500)
        
        # Second request to basic succeeds
        stub_request(:post, "#{service.instance_variable_get(:@ai_service_url)}/extract/structured")
          .with(body: hash_including('provider' => 'basic'))
          .to_return(status: 200, body: successful_ai_response.to_json)

        result = service.extract_structured_data(file_path, provider: 'ollama')
        
        expect(result['success']).to be true
        expect(WebMock).to have_requested(:post, "#{service.instance_variable_get(:@ai_service_url)}/extract/structured")
          .with(body: hash_including('provider' => 'ollama')).once
        expect(WebMock).to have_requested(:post, "#{service.instance_variable_get(:@ai_service_url)}/extract/structured")
          .with(body: hash_including('provider' => 'basic')).once
      end
    end
  end

  describe '#available_providers' do
    context 'when service is available' do
      before do
        providers_response = {
          'providers' => {
            'ollama' => { 'available' => true, 'status' => 'ready' },
            'basic' => { 'available' => true, 'status' => 'ready' }
          },
          'recommended' => 'ollama'
        }
        
        stub_request(:get, "#{service.instance_variable_get(:@ai_service_url)}/ai-providers")
          .to_return(
            status: 200,
            body: providers_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns available providers' do
        result = service.available_providers
        
        expect(result['providers']).to have_key('ollama')
        expect(result['providers']).to have_key('basic')
        expect(result['recommended']).to eq('ollama')
      end
    end

    context 'when service is unavailable' do
      before do
        stub_request(:get, "#{service.instance_variable_get(:@ai_service_url)}/ai-providers")
          .to_return(status: 500)
      end

      it 'returns fallback providers' do
        result = service.available_providers
        
        expect(result['providers']).to have_key('basic')
        expect(result['providers']['basic']['available']).to be true
        expect(result['recommended']).to eq('basic')
      end
    end
  end
end
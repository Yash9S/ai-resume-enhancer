# spec/jobs/resume_processing_job_spec.rb
require 'rails_helper'

RSpec.describe ResumeProcessingJob, type: :job do
  include ActiveJob::TestHelper
  
  let(:user) { create(:user) }
  let(:resume) { create(:resume, user: user) }
  let(:job_description) { create(:job_description, user: user) }
  
  # Mock AI Service Response Data
  let(:successful_extraction_response) do
    {
      'job_id' => '1234-5678-9012',
      'success' => true,
      'original_text' => 'Jane Smith\njane.smith@email.com\n+1-555-987-6543\nSenior Ruby Developer...',
      'structured_data' => {
        'summary' => 'Senior Ruby developer with 8 years of experience',
        'contact_info' => {},
        'skills' => [],
        'experience' => [],
        'education' => [],
        'ai_response' => '```json
{
  "contact_info": {
    "name": "Jane Smith",
    "email": "jane.smith@email.com", 
    "phone": "+1-555-987-6543",
    "location": "New York, NY"
  },
  "summary": "Senior Ruby developer with extensive Rails experience",
  "skills": [
    "Languages: Ruby, JavaScript, Go",
    "Frameworks: Rails, Sinatra, React",
    "Databases: PostgreSQL, Redis, MongoDB"
  ],
  "experience": [
    {
      "company": "StartupCorp",
      "position": "Senior Ruby Developer", 
      "duration": "2020 - Present",
      "description": "Led development of scalable web applications"
    },
    {
      "company": "TechFirm",
      "position": "Ruby Developer",
      "duration": "2018 - 2020", 
      "description": "Built REST APIs and microservices"
    }
  ],
  "education": [
    {
      "degree": "MS Computer Science",
      "institution": "State University",
      "year": "2018"
    }
  ]
}
```',
        'provider_used' => 'ollama',
        'extraction_method' => 'ai_text_parsing'
      },
      'ai_provider' => 'ollama',
      'timestamp' => Time.current.iso8601
    }
  end

  let(:fallback_extraction_response) do
    {
      'data' => {
        'personal_info' => {
          'name' => 'Test User',
          'email' => nil,
          'phone' => nil,
          'location' => nil
        },
        'summary' => 'Unable to extract summary - please review manually',
        'skills' => [],
        'experience' => [],
        'education' => [],
        'raw_text' => 'Extraction failed - manual review needed'
      },
      'provider_used' => 'fallback',
      'confidence_score' => 0.1,
      'text' => 'Extraction failed - manual review needed'
    }
  end

  before do
    # Mock file attachment
    resume.file.attach(
      io: StringIO.new('PDF content'),
      filename: 'test_resume.pdf',
      content_type: 'application/pdf'
    )
  end

  describe '#perform' do
    context 'with successful AI extraction' do
      before do
        allow_any_instance_of(AiExtractionService).to receive(:health_check).and_return(true)
        allow_any_instance_of(AiExtractionService).to receive(:extract_structured_data)
          .and_return(successful_extraction_response)
      end

      it 'updates resume status to processing' do
        expect {
          ResumeProcessingJob.perform_now(resume.id)
          resume.reload
        }.to change(resume, :processing_status).to('processing')
      end

      it 'extracts contact information correctly' do
        ResumeProcessingJob.perform_now(resume.id)
        resume.reload
        
        expect(resume.extracted_name).to eq('Jane Smith')
        expect(resume.extracted_email).to eq('jane.smith@email.com')
        expect(resume.extracted_phone).to eq('+1-555-987-6543')
        expect(resume.extracted_location).to eq('New York, NY')
      end

      it 'parses and stores skills correctly' do
        ResumeProcessingJob.perform_now(resume.id)
        resume.reload
        
        skills = JSON.parse(resume.extracted_skills)
        expect(skills).to include('Ruby', 'JavaScript', 'Go')
        expect(skills).to include('Rails', 'Sinatra', 'React')
        expect(skills).to include('PostgreSQL', 'Redis', 'MongoDB')
        expect(skills.length).to eq(9) # Total individual skills extracted
      end

      it 'stores experience data as JSON' do
        ResumeProcessingJob.perform_now(resume.id)
        resume.reload
        
        experience = JSON.parse(resume.extracted_experience)
        expect(experience).to be_an(Array)
        expect(experience.length).to eq(2)
        
        first_job = experience.first
        expect(first_job['company']).to eq('StartupCorp')
        expect(first_job['position']).to eq('Senior Ruby Developer')
        expect(first_job['duration']).to eq('2020 - Present')
        expect(first_job['description']).to include('Led development')
      end

      it 'stores education data as JSON' do
        ResumeProcessingJob.perform_now(resume.id)
        resume.reload
        
        education = JSON.parse(resume.extracted_education)
        expect(education).to be_an(Array)
        expect(education.length).to eq(1)
        
        degree = education.first
        expect(degree['degree']).to eq('MS Computer Science')
        expect(degree['institution']).to eq('State University')
        expect(degree['year']).to eq('2018')
      end

      it 'stores professional summary' do
        ResumeProcessingJob.perform_now(resume.id)
        resume.reload
        
        expect(resume.extracted_summary).to eq('Senior Ruby developer with extensive Rails experience')
      end

      it 'stores original extracted text' do
        ResumeProcessingJob.perform_now(resume.id)
        resume.reload
        
        expect(resume.extracted_text).to include('Jane Smith')
        expect(resume.extracted_text).to include('jane.smith@email.com')
        expect(resume.extracted_text).to include('Senior Ruby Developer')
      end

      it 'tracks AI provider used' do
        ResumeProcessingJob.perform_now(resume.id)
        resume.reload
        
        expect(resume.ai_provider_used).to eq('ollama')
      end

      it 'sets processing status to completed' do
        ResumeProcessingJob.perform_now(resume.id)
        resume.reload
        
        expect(resume.processing_status).to eq('completed')
        expect(resume.status).to eq('processed')
        expect(resume.processing_completed_at).to be_present
      end

      it 'sets extraction confidence score' do
        ResumeProcessingJob.perform_now(resume.id)
        resume.reload
        
        expect(resume.extraction_confidence).to eq(0.8)
      end

      it 'records processing timestamps' do
        freeze_time do
          ResumeProcessingJob.perform_now(resume.id)
          resume.reload
          
          expect(resume.processing_started_at).to be_within(1.second).of(Time.current)
          expect(resume.processing_completed_at).to be_within(1.second).of(Time.current)
        end
      end
    end

    context 'with AI service health check failure' do
      before do
        allow_any_instance_of(AiExtractionService).to receive(:health_check).and_return(false)
        allow_any_instance_of(AiExtractionService).to receive(:extract_structured_data)
          .and_return(successful_extraction_response)
      end

      it 'falls back to basic processing' do
        expect_any_instance_of(AiExtractionService).to receive(:extract_structured_data)
          .with(anything, provider: 'basic')
          .and_return(successful_extraction_response)
        
        ResumeProcessingJob.perform_now(resume.id)
      end
    end

    context 'with AI extraction failure' do
      before do
        allow_any_instance_of(AiExtractionService).to receive(:health_check).and_return(true)
        allow_any_instance_of(AiExtractionService).to receive(:extract_structured_data)
          .and_return({ error: 'AI service unavailable', provider_tried: 'ollama' })
      end

      it 'creates fallback extraction data' do
        ResumeProcessingJob.perform_now(resume.id)
        resume.reload
        
        expect(resume.extracted_name).to eq(resume.title) # Falls back to resume title
        expect(resume.extracted_summary).to eq('Unable to extract summary - please review manually')
        expect(JSON.parse(resume.extracted_skills)).to eq([])
        expect(JSON.parse(resume.extracted_experience)).to eq([])
        expect(JSON.parse(resume.extracted_education)).to eq([])
      end

      it 'still completes processing with fallback data' do
        ResumeProcessingJob.perform_now(resume.id)
        resume.reload
        
        expect(resume.processing_status).to eq('completed')
        expect(resume.has_ai_data?).to be true # Because extracted_name is present
      end
    end

    context 'with malformed AI response JSON' do
      let(:malformed_response) do
        {
          'success' => true,
          'structured_data' => {
            'ai_response' => '```json\n{\n  "contact_info": {\n    "name": "John"\n    invalid json\n}\n```'
          }
        }
      end

      before do
        allow_any_instance_of(AiExtractionService).to receive(:health_check).and_return(true)
        allow_any_instance_of(AiExtractionService).to receive(:extract_structured_data)
          .and_return(malformed_response)
      end

      it 'handles JSON parsing errors gracefully' do
        expect {
          ResumeProcessingJob.perform_now(resume.id)
        }.not_to raise_error
        
        resume.reload
        expect(resume.processing_status).to eq('completed')
        expect(resume.extracted_name).to be_present
      end
    end

    context 'with job description matching' do
      before do
        allow_any_instance_of(AiExtractionService).to receive(:health_check).and_return(true)
        allow_any_instance_of(AiExtractionService).to receive(:extract_structured_data)
          .and_return(successful_extraction_response)
        allow_any_instance_of(AiExtractionService).to receive(:enhance_resume)
          .and_return({
            'enhanced_resume' => 'Enhanced content with job matching',
            'provider_used' => 'ollama'
          })
      end

      it 'performs enhancement when job description provided' do
        expect_any_instance_of(AiExtractionService).to receive(:enhance_resume)
          .with(successful_extraction_response, job_description.content, provider: 'ollama')
        
        ResumeProcessingJob.perform_now(resume.id, job_description.id, 'ollama')
      end

      it 'handles enhancement timeout gracefully' do
        allow_any_instance_of(AiExtractionService).to receive(:enhance_resume)
          .and_raise(Timeout::Error)
        
        expect {
          ResumeProcessingJob.perform_now(resume.id, job_description.id, 'ollama')
        }.not_to raise_error
        
        resume.reload
        expect(resume.processing_status).to eq('completed')
      end
    end

    context 'with unexpected errors' do
      before do
        allow_any_instance_of(AiExtractionService).to receive(:health_check)
          .and_raise(StandardError, 'Unexpected error')
      end

      it 'handles unexpected errors and marks as failed' do
        ResumeProcessingJob.perform_now(resume.id)
        resume.reload
        
        expect(resume.processing_status).to eq('failed')
        expect(resume.status).to eq('failed')
        expect(resume.processing_error).to include('Unexpected error')
      end

      it 'broadcasts failure to user' do
        expect {
          ResumeProcessingJob.perform_now(resume.id)
        }.to have_broadcasted_to("user_#{resume.user_id}_resumes")
          .with(hash_including(type: 'resume_processing_failed'))
      end
    end

    context 'data consistency validation' do
      before do
        allow_any_instance_of(AiExtractionService).to receive(:health_check).and_return(true)
        allow_any_instance_of(AiExtractionService).to receive(:extract_structured_data)
          .and_return(successful_extraction_response)
      end

      it 'ensures all extracted fields are properly formatted' do
        ResumeProcessingJob.perform_now(resume.id)
        resume.reload
        
        # Validate JSON fields can be parsed
        expect { JSON.parse(resume.extracted_skills) }.not_to raise_error
        expect { JSON.parse(resume.extracted_experience) }.not_to raise_error
        expect { JSON.parse(resume.extracted_education) }.not_to raise_error
        
        # Validate data types
        expect(resume.extracted_name).to be_a(String)
        expect(resume.extracted_email).to be_a(String).or(be_nil)
        expect(resume.extracted_phone).to be_a(String).or(be_nil)
        expect(resume.extraction_confidence).to be_a(Numeric)
      end

      it 'maintains referential integrity' do
        original_user_id = resume.user_id
        original_title = resume.title
        
        ResumeProcessingJob.perform_now(resume.id)
        resume.reload
        
        expect(resume.user_id).to eq(original_user_id)
        expect(resume.title).to eq(original_title)
      end

      it 'validates email format when extracted' do
        ResumeProcessingJob.perform_now(resume.id)
        resume.reload
        
        if resume.extracted_email.present?
          expect(resume.extracted_email).to match(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
        end
      end

      it 'ensures skills are individual items, not grouped strings' do
        ResumeProcessingJob.perform_now(resume.id)
        resume.reload
        
        skills = JSON.parse(resume.extracted_skills)
        skills.each do |skill|
          expect(skill).not_to include(':') # Should be individual skills, not "Languages: Ruby, JS"
          expect(skill.length).to be < 50 # Individual skills should be reasonably short
        end
      end
    end

    context 'performance and timeout validation' do
      it 'completes within reasonable time' do
        allow_any_instance_of(AiExtractionService).to receive(:health_check).and_return(true)
        allow_any_instance_of(AiExtractionService).to receive(:extract_structured_data)
          .and_return(successful_extraction_response)
        
        start_time = Time.current
        ResumeProcessingJob.perform_now(resume.id)
        end_time = Time.current
        
        processing_time = end_time - start_time
        expect(processing_time).to be < 5.seconds # Should be very fast in test environment
      end

      it 'sets job timeout correctly' do
        expect(ResumeProcessingJob.timeout).to eq(3.minutes)
      end
    end

    context 'ActionCable broadcasting' do
      before do
        allow_any_instance_of(AiExtractionService).to receive(:health_check).and_return(true)
        allow_any_instance_of(AiExtractionService).to receive(:extract_structured_data)
          .and_return(successful_extraction_response)
      end

      it 'broadcasts success message on completion' do
        expect {
          ResumeProcessingJob.perform_now(resume.id)
        }.to have_broadcasted_to("user_#{resume.user_id}_resumes")
          .with(hash_including(
            type: 'resume_processed',
            resume_id: resume.id,
            status: 'completed'
          ))
      end

      it 'includes processing time in broadcast' do
        expect {
          ResumeProcessingJob.perform_now(resume.id)
        }.to have_broadcasted_to("user_#{resume.user_id}_resumes")
          .with(hash_including(:processing_time))
      end
    end
  end

  describe 'retry configuration' do
    it 'has correct retry settings for timeout errors' do
      expect(ResumeProcessingJob.retry_on_queue_adapter)
        .to include(have_attributes(exception_class_name: 'Timeout::Error'))
    end

    it 'has limited retry attempts for fast failure' do
      timeout_retry = ResumeProcessingJob.retry_on_queue_adapter
        .find { |r| r.exception_class_name == 'Timeout::Error' }
      
      expect(timeout_retry.attempts).to eq(2)
    end
  end
end
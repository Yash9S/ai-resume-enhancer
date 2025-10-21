# spec/models/resume_spec.rb
require 'rails_helper'

RSpec.describe Resume, type: :model do
  let(:user) { create(:user) }
  
  describe 'data validation and consistency' do
    let(:resume) { build(:resume, user: user) }

    it 'validates presence of required fields' do
      expect(resume).to validate_presence_of(:title)
      expect(resume).to validate_presence_of(:file)
    end

    it 'validates file type' do
      resume.file.attach(
        io: StringIO.new('invalid content'),
        filename: 'test.txt',
        content_type: 'text/plain'
      )
      
      expect(resume).not_to be_valid
      expect(resume.errors[:file]).to include('must be a PDF or DOCX file')
    end

    it 'accepts valid PDF files' do
      resume.file.attach(
        io: StringIO.new('%PDF-1.4 fake pdf content'),
        filename: 'resume.pdf',
        content_type: 'application/pdf'
      )
      
      expect(resume).to be_valid
    end

    it 'accepts valid DOCX files' do
      resume.file.attach(
        io: StringIO.new('docx content'),
        filename: 'resume.docx',
        content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      )
      
      expect(resume).to be_valid
    end

    context 'status enums' do
      it 'has correct status enum values' do
        expect(Resume.statuses.keys).to match_array(%w[uploaded processing processed failed])
      end

      it 'has correct processing_status enum values' do
        expect(Resume.processing_statuses.keys).to match_array(%w[pending queued processing completed failed])
      end

      it 'defaults to uploaded status' do
        resume = Resume.new
        expect(resume.status).to eq('uploaded')
      end

      it 'defaults to pending processing_status' do
        resume = Resume.new
        expect(resume.processing_status).to eq('pending')
      end
    end

    context 'user association' do
      it 'belongs to a user' do
        resume = create(:resume, user: user)
        expect(resume.user).to eq(user)
      end

      it 'stores user_id for cross-schema access' do
        resume = create(:resume, user: user)
        expect(resume.user_id).to eq(user.id)
      end

      it 'handles user assignment' do
        resume = Resume.new
        resume.user = user
        expect(resume.user_id).to eq(user.id)
      end
    end
  end

  describe 'AI extraction data methods' do
    let(:resume) do
      create(:resume, :with_ai_data, user: user,
        extracted_name: 'John Doe',
        extracted_email: 'john@example.com',
        extracted_phone: '+1-555-123-4567',
        extracted_location: 'San Francisco, CA',
        extracted_summary: 'Experienced software engineer',
        extracted_skills: '["Ruby", "JavaScript", "Python", "Rails", "React"]',
        extracted_experience: '[
          {
            "company": "TechCorp",
            "position": "Senior Developer", 
            "duration": "2020-Present",
            "description": "Led development team"
          }
        ]',
        extracted_education: '[
          {
            "degree": "BS Computer Science",
            "institution": "University of Tech",
            "year": "2018"
          }
        ]'
      )
    end

    describe '#has_ai_data?' do
      it 'returns true when AI data is present' do
        expect(resume.has_ai_data?).to be true
      end

      it 'returns false when no AI data is present' do
        empty_resume = create(:resume, user: user)
        expect(empty_resume.has_ai_data?).to be false
      end

      it 'returns true if only extracted_name is present' do
        resume_with_name = create(:resume, user: user, extracted_name: 'Jane Doe')
        expect(resume_with_name.has_ai_data?).to be true
      end

      it 'returns true if only extracted_email is present' do
        resume_with_email = create(:resume, user: user, extracted_email: 'jane@example.com')
        expect(resume_with_email.has_ai_data?).to be true
      end

      it 'returns true if only extracted_text is present' do
        resume_with_text = create(:resume, user: user, extracted_text: 'Some extracted text')
        expect(resume_with_text.has_ai_data?).to be true
      end
    end

    describe '#ai_extracted_data' do
      it 'returns structured hash with all data' do
        data = resume.ai_extracted_data
        
        expect(data).to be_a(Hash)
        expect(data[:name]).to eq('John Doe')
        expect(data[:email]).to eq('john@example.com')
        expect(data[:phone]).to eq('+1-555-123-4567')
        expect(data[:location]).to eq('San Francisco, CA')
        expect(data[:summary]).to eq('Experienced software engineer')
      end

      it 'parses skills JSON correctly' do
        data = resume.ai_extracted_data
        
        expect(data[:skills]).to be_an(Array)
        expect(data[:skills]).to eq(['Ruby', 'JavaScript', 'Python', 'Rails', 'React'])
      end

      it 'parses experience JSON correctly' do
        data = resume.ai_extracted_data
        
        expect(data[:experience]).to be_an(Array)
        expect(data[:experience].length).to eq(1)
        
        exp = data[:experience].first
        expect(exp['company']).to eq('TechCorp')
        expect(exp['position']).to eq('Senior Developer')
        expect(exp['duration']).to eq('2020-Present')
        expect(exp['description']).to eq('Led development team')
      end

      it 'parses education JSON correctly' do
        data = resume.ai_extracted_data
        
        expect(data[:education]).to be_an(Array)
        expect(data[:education].length).to eq(1)
        
        edu = data[:education].first
        expect(edu['degree']).to eq('BS Computer Science')
        expect(edu['institution']).to eq('University of Tech')
        expect(edu['year']).to eq('2018')
      end

      it 'handles empty JSON fields gracefully' do
        resume.update!(
          extracted_skills: nil,
          extracted_experience: '',
          extracted_education: '[]'
        )
        
        data = resume.ai_extracted_data
        
        expect(data[:skills]).to eq([])
        expect(data[:experience]).to eq([])
        expect(data[:education]).to eq([])
      end

      it 'handles malformed JSON gracefully' do
        resume.update!(extracted_skills: 'invalid json')
        
        data = resume.ai_extracted_data
        
        expect(data[:skills]).to eq([])
      end
    end

    describe 'data consistency validation' do
      it 'ensures JSON fields contain valid JSON when present' do
        resume = create(:resume, user: user)
        
        # Valid JSON
        resume.update!(extracted_skills: '["Ruby", "JavaScript"]')
        expect { JSON.parse(resume.extracted_skills) }.not_to raise_error
        
        # Empty string should be handled
        resume.update!(extracted_skills: '')
        expect(resume.ai_extracted_data[:skills]).to eq([])
        
        # Nil should be handled
        resume.update!(extracted_skills: nil)
        expect(resume.ai_extracted_data[:skills]).to eq([])
      end

      it 'validates email format when present' do
        resume = create(:resume, user: user)
        
        # Valid email
        resume.update!(extracted_email: 'test@example.com')
        expect(resume.extracted_email).to match(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
        
        # Invalid email should be stored as-is (extraction might have issues)
        resume.update!(extracted_email: 'invalid-email')
        expect(resume.extracted_email).to eq('invalid-email')
      end

      it 'ensures confidence score is numeric when present' do
        resume = create(:resume, user: user, extraction_confidence: 0.85)
        
        expect(resume.extraction_confidence).to be_a(Numeric)
        expect(resume.extraction_confidence).to be_between(0, 1)
      end

      it 'tracks processing timestamps correctly' do
        resume = create(:resume, user: user)
        
        start_time = Time.current
        resume.update!(
          processing_started_at: start_time,
          processing_completed_at: start_time + 30.seconds
        )
        
        expect(resume.processing_started_at).to eq(start_time)
        expect(resume.processing_completed_at).to eq(start_time + 30.seconds)
      end
    end
  end

  describe 'processing timeout methods' do
    let(:resume) { create(:resume, user: user) }

    describe '#processing_timeout?' do
      it 'returns false when not processing' do
        expect(resume.processing_timeout?).to be false
      end

      it 'returns false when processing just started' do
        resume.update!(
          processing_status: 'processing',
          processing_started_at: 1.minute.ago
        )
        
        expect(resume.processing_timeout?).to be false
      end

      it 'returns true when processing has timed out' do
        resume.update!(
          processing_status: 'processing',
          processing_started_at: 5.minutes.ago
        )
        
        expect(resume.processing_timeout?).to be true
      end

      it 'returns false when processing is completed' do
        resume.update!(
          processing_status: 'completed',
          processing_started_at: 5.minutes.ago,
          processing_completed_at: 2.minutes.ago
        )
        
        expect(resume.processing_timeout?).to be false
      end

      it 'returns false when processing failed' do
        resume.update!(
          processing_status: 'failed',
          processing_started_at: 5.minutes.ago
        )
        
        expect(resume.processing_timeout?).to be false
      end
    end

    describe '#reset_if_timeout!' do
      it 'resets stuck processing jobs' do
        resume.update!(
          processing_status: 'processing',
          processing_started_at: 5.minutes.ago,
          processing_error: 'Some error'
        )
        
        result = resume.reset_if_timeout!
        resume.reload
        
        expect(result).to be true
        expect(resume.processing_status).to eq('pending')
        expect(resume.processing_error).to eq('Processing timeout - reset for retry')
        expect(resume.processing_started_at).to be_nil
      end

      it 'does not reset non-timeout jobs' do
        resume.update!(
          processing_status: 'processing',
          processing_started_at: 1.minute.ago
        )
        
        result = resume.reset_if_timeout!
        
        expect(result).to be false
        expect(resume.processing_status).to eq('processing')
      end
    end
  end

  describe '#process_with_ai!' do
    let(:resume) { create(:resume, user: user) }

    it 'resets processing status and queues job' do
      resume.update!(processing_status: 'failed', processing_error: 'Previous error')
      
      expect {
        resume.process_with_ai!
      }.to have_enqueued_job(ResumeProcessingJob).with(resume.id, nil, 'ollama')
      
      resume.reload
      expect(resume.processing_status).to eq('queued')
      expect(resume.processing_error).to be_nil
      expect(resume.processing_started_at).to be_nil
    end

    it 'accepts job description and provider parameters' do
      job_description_id = 123
      
      expect {
        resume.process_with_ai!(job_description_id, 'basic')
      }.to have_enqueued_job(ResumeProcessingJob).with(resume.id, job_description_id, 'basic')
    end

    it 'uses high priority queue' do
      expect {
        resume.process_with_ai!
      }.to have_enqueued_job(ResumeProcessingJob).on_queue('high')
    end
  end

  describe 'file handling' do
    let(:resume) { create(:resume, user: user) }

    before do
      resume.file.attach(
        io: StringIO.new('PDF content'),
        filename: 'test_resume.pdf',
        content_type: 'application/pdf'
      )
    end

    describe '#file_size' do
      it 'returns file size when attached' do
        expect(resume.file_size).to eq(11) # "PDF content".bytesize
      end

      it 'returns 0 when no file attached' do
        resume.file.purge
        expect(resume.file_size).to eq(0)
      end
    end

    describe '#processed?' do
      it 'returns true when status is processed' do
        resume.update!(status: 'processed')
        expect(resume.processed?).to be true
      end

      it 'returns false when status is not processed' do
        resume.update!(status: 'uploaded')
        expect(resume.processed?).to be false
      end
    end
  end

  describe 'multitenancy' do
    let(:resume) { create(:resume, user: user) }

    it 'tracks current tenant' do
      Apartment::Tenant.switch('test') do
        expect(resume.current_tenant).to eq('test')
      end
    end

    it 'maintains user relationship across tenants' do
      Apartment::Tenant.switch('test') do
        resume = create(:resume, user: user)
        
        # Should be able to access user from public schema
        expect(resume.user).to eq(user)
        expect(resume.user_id).to eq(user.id)
      end
    end
  end

  describe 'processing time calculation' do
    let(:resume) { create(:resume, user: user) }

    it 'calculates processing time correctly' do
      start_time = Time.current
      end_time = start_time + 45.seconds
      
      resume.update!(
        processing_started_at: start_time,
        processing_completed_at: end_time
      )
      
      expect(resume.processing_time).to eq(45)
    end

    it 'returns nil when timestamps are missing' do
      expect(resume.processing_time).to be_nil
      
      resume.update!(processing_started_at: Time.current)
      expect(resume.processing_time).to be_nil
    end
  end

  describe 'scopes' do
    let!(:recent_resume) { create(:resume, user: user, created_at: 1.day.ago) }
    let!(:old_resume) { create(:resume, user: user, created_at: 1.week.ago) }
    let!(:ai_processed_resume) { create(:resume, :with_ai_data, user: user) }
    let!(:pending_resume) { create(:resume, user: user, processing_status: 'pending') }

    describe '.recent' do
      it 'orders by created_at desc' do
        resumes = Resume.recent
        expect(resumes.first.created_at).to be > resumes.last.created_at
      end
    end

    describe '.ai_processed' do
      it 'includes only completed processing status' do
        resumes = Resume.ai_processed
        expect(resumes).to include(ai_processed_resume)
        expect(resumes).not_to include(pending_resume)
      end
    end

    describe '.needs_processing' do
      it 'includes pending and failed statuses' do
        failed_resume = create(:resume, user: user, processing_status: 'failed')
        
        resumes = Resume.needs_processing
        expect(resumes).to include(pending_resume, failed_resume)
        expect(resumes).not_to include(ai_processed_resume)
      end
    end
  end
end
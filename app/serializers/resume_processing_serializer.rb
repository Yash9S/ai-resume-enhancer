# app/serializers/resume_processing_serializer.rb
class ResumeProcessingSerializer < ActiveModel::Serializer
  attributes :id, :analysis, :match_score, :created_at, :updated_at
  
  belongs_to :resume, serializer: ResumeSerializer
  belongs_to :job_description, serializer: JobDescriptionSerializer
  
  def analysis
    object.analysis.present? ? JSON.parse(object.analysis) : {}
  rescue JSON::ParserError
    {}
  end
  
  def match_score
    analysis_data = analysis
    analysis_data['match_score'] || 0
  end
end
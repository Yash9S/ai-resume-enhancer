# app/serializers/job_description_serializer.rb
class JobDescriptionSerializer < ActiveModel::Serializer
  attributes :id, :title, :company, :content, :created_at, :updated_at
  
  belongs_to :user, serializer: UserSerializer
  has_many :resume_processings, serializer: ResumeProcessingSerializer
end
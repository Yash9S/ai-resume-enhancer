# app/serializers/resume_serializer.rb
class ResumeSerializer < ActiveModel::Serializer
  attributes :id, :filename, :status, :extracted_content, :enhanced_content, 
             :error_message, :created_at, :updated_at, :file_url, :file_size
  
  belongs_to :user, serializer: UserSerializer
  has_many :resume_processings, serializer: ResumeProcessingSerializer
  
  def filename
    object.file.attached? ? object.file.filename.to_s : 'No file attached'
  end
  
  def file_url
    object.file.attached? ? Rails.application.routes.url_helpers.rails_blob_url(object.file) : nil
  end
  
  def file_size
    object.file.attached? ? object.file.byte_size : 0
  end
  
  def status
    object.status.humanize
  end
end
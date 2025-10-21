class JobDescription < ApplicationRecord
  # Note: Users are in public schema, so we store user_id but don't enforce FK constraint
  has_many :resume_processings, dependent: :destroy

  validates :title, presence: true
  validates :company, presence: true
  validates :description, presence: true

  # Ensure content is populated from description for backward compatibility
  before_save :sync_content_with_description

  scope :recent, -> { order(created_at: :desc) }
  scope :for_current_tenant, -> { all } # Already tenant-scoped via apartment gem

  # Get user from public schema (cross-schema relationship)
  def user
    return nil unless user_id
    
    Apartment::Tenant.switch('public') do
      User.find_by(id: user_id)
    end
  end
  
  # Set user (for compatibility with existing code)
  def user=(user_obj)
    self.user_id = user_obj&.id
  end

  def keywords
    # Extract keywords from job description content
    # This is a simple implementation, can be enhanced with NLP
    description_content = description.present? ? description : content
    return [] unless description_content
    description_content.downcase.split(/\W+/).uniq.select { |word| word.length > 3 }
  end

  # Tenant-aware method to get current tenant context
  def current_tenant
    Apartment::Tenant.current
  end

  def requirements
    # Extract requirements section if available
    description_content = description.present? ? description : content
    return [] unless description_content
    
    lines = description_content.split("\n")
    requirements_start = lines.find_index { |line| line.downcase.include?('requirement') }
    return [] unless requirements_start

    requirements_lines = []
    (requirements_start + 1...lines.length).each do |i|
      break if lines[i].strip.empty? && requirements_lines.any?
      requirements_lines << lines[i].strip if lines[i].strip.present?
    end

    requirements_lines
  end

  private

  def sync_content_with_description
    # Keep content in sync with description for backward compatibility
    self.content = description if description.present?
  end
end
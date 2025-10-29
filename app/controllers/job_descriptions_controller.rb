class JobDescriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_job_description, only: [:show, :edit, :update, :destroy]

  def index
    @job_descriptions = current_user.job_descriptions_in_current_tenant.order(created_at: :desc)
  rescue => e
    Rails.logger.error "JobDescriptions#index error: #{e.message}"
    @job_descriptions = []
  end

  def show
    @resumes = current_user.resumes_in_current_tenant.recent
    @related_processings = @job_description.resume_processings.recent.includes(:resume)
  end

  def new
    @job_description = JobDescription.new(user_id: current_user.id)
  end

  def create
    @job_description = JobDescription.new(job_description_params.merge(user_id: current_user.id))

    if @job_description.save
      # Extract keywords and requirements after saving
      extract_job_data
      redirect_to @job_description, notice: 'Job description was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @job_description.update(job_description_params)
      extract_job_data
      redirect_to @job_description, notice: 'Job description was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @job_description.destroy
    redirect_to job_descriptions_path, notice: 'Job description was successfully deleted.'
  end

  private

  def set_job_description
    @job_description = current_user.job_descriptions_in_current_tenant.find(params[:id])
  end

  def job_description_params
    params.require(:job_description).permit(:title, :content, :company_name, :location, 
                                           :company, :description, :employment_type, 
                                           :experience_level, :salary_range, :required_skills)
  end

  def extract_job_data
    # Extract keywords and requirements from the job description
    keywords = @job_description.keywords
    requirements = @job_description.requirements

    @job_description.update(
      extracted_keywords: keywords,
      requirements: requirements
    )
  end
end
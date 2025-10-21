# Example API-only controller for the Business Logic service

class Api::V1::ResumesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_resume, only: [:show, :update, :destroy, :process_resume]

  # GET /api/v1/resumes
  def index
    @resumes = current_user.resumes.includes(:resume_processings)
                          .page(params[:page])
                          .per(params[:per_page] || 10)
                          .order(created_at: :desc)
    
    render json: {
      resumes: @resumes.map(&method(:serialize_resume)),
      pagination: {
        current_page: @resumes.current_page,
        total_pages: @resumes.total_pages,
        total_count: @resumes.total_count
      }
    }
  end

  # GET /api/v1/resumes/:id
  def show
    render json: {
      resume: serialize_resume(@resume),
      processings: @resume.resume_processings.recent.map(&method(:serialize_processing))
    }
  end

  # POST /api/v1/resumes
  def create
    @resume = current_user.resumes.build(resume_params)
    
    if @resume.save
      render json: { resume: serialize_resume(@resume) }, status: :created
    else
      render json: { errors: @resume.errors }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/resumes/:id
  def update
    if @resume.update(resume_params)
      render json: { resume: serialize_resume(@resume) }
    else
      render json: { errors: @resume.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/resumes/:id
  def destroy
    @resume.destroy
    head :no_content
  end

  # POST /api/v1/resumes/:id/process
  def process_resume
    job_description_id = params[:job_description_id]
    job_description = job_description_id.present? ? 
                     current_user.job_descriptions.find(job_description_id) : nil
    
    # Instead of ProcessResumeJob, call AI service directly
    ProcessResumeWithAIServiceJob.perform_later(@resume, job_description, current_user)
    
    @resume.update(status: :processing)
    
    render json: { 
      message: 'Resume processing started',
      resume: serialize_resume(@resume) 
    }
  end

  private

  def set_resume
    @resume = current_user.resumes.find(params[:id])
  end

  def resume_params
    params.require(:resume).permit(:title, :file)
  end

  def serialize_resume(resume)
    {
      id: resume.id,
      title: resume.title,
      filename: resume.file.attached? ? resume.file.filename : nil,
      file_size: resume.file.attached? ? resume.file.byte_size : nil,
      status: resume.status,
      extracted_content: resume.extracted_content,
      enhanced_content: resume.enhanced_content,
      extracted_data: resume.extracted_data,
      created_at: resume.created_at,
      updated_at: resume.updated_at,
      file_url: resume.file.attached? ? rails_blob_path(resume.file) : nil
    }
  end

  def serialize_processing(processing)
    {
      id: processing.id,
      processing_type: processing.processing_type,
      status: processing.status,
      match_score: processing.match_score,
      result: processing.result,
      started_at: processing.started_at,
      completed_at: processing.completed_at,
      job_description: processing.job_description&.title
    }
  end
end
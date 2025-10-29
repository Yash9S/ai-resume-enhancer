class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :check_admin_subdomain_access!

  def index
    begin
      # Check if required tables exist before querying
      unless table_exists?('resumes') && table_exists?('job_descriptions')
        @stats = { total_resumes: 0, processed_resumes: 0, total_job_descriptions: 0, successful_processings: 0 }
        @resumes = current_user.admin? ? Resume.none : current_user.resumes_in_current_tenant.none
        @job_descriptions = current_user.admin? ? JobDescription.none : current_user.job_descriptions_in_current_tenant.none
        flash[:alert] = "Tenant database schema is not properly initialized. Please contact an administrator."
        return
      end

      # Get data for both formats
      @resumes = current_user.admin? ? Resume.includes(:user) : current_user.resumes_in_current_tenant.includes(:user)
      @job_descriptions = current_user.admin? ? JobDescription.includes(:user) : current_user.job_descriptions_in_current_tenant.includes(:user)
      
      # Provide stats for both ERB fallback and React components
      @stats = {
        total_resumes: @resumes.count,
        processed_resumes: @resumes.where(processing_status: 'completed').count,
        total_job_descriptions: @job_descriptions.count,
        successful_processings: @resumes.where(processing_status: 'completed').count
      }
    rescue ActiveRecord::StatementInvalid => e
      # Handle database errors gracefully
      Rails.logger.error "Database error in dashboard index: #{e.message}"
      @stats = { total_resumes: 0, processed_resumes: 0, total_job_descriptions: 0, successful_processings: 0 }
      @resumes = current_user.admin? ? Resume.none : current_user.resumes_in_current_tenant.none
      @job_descriptions = current_user.admin? ? JobDescription.none : current_user.job_descriptions_in_current_tenant.none
      flash[:alert] = "Unable to load dashboard data. Please try again or contact support if the problem persists."
    end

    respond_to do |format|
      format.html do
        # Additional data for ERB fallback
        begin
          @recent_resumes = @resumes.limit(5).order(created_at: :desc)
          @recent_job_descriptions = @job_descriptions.order(created_at: :desc).limit(5)
          @recent_processings = @resumes.where(processing_status: 'completed').order(updated_at: :desc).limit(10)
        rescue ActiveRecord::StatementInvalid => e
          Rails.logger.error "Database error loading recent items: #{e.message}"
          @recent_resumes = Resume.none
          @recent_job_descriptions = JobDescription.none
          @recent_processings = Resume.none
        end
      end
      
      format.json do
        render json: {
          dashboard: {
            resumes: {
              stats: {
                total: @stats[:total_resumes],
                processed: @stats[:processed_resumes],
                processing: @resumes.respond_to?(:where) ? @resumes.where(status: 'processing').count : 0,
                failed: @resumes.respond_to?(:where) ? @resumes.where(status: 'failed').count : 0
              }
            },
            job_descriptions: {
              total_count: @stats[:total_job_descriptions]
            },
            user: {
              name: current_user.email,
              role: current_user.role,
              is_admin: current_user.admin?
            }
          }
        }
      end
    end
  end

  def react_index
    # Serve the React-powered dashboard with data
    begin
      # Check if required tables exist before querying
      unless table_exists?('resumes') && table_exists?('job_descriptions')
        # Redirect to a safe page if tables don't exist
        redirect_to root_path, alert: "Tenant database schema is not properly initialized. Please contact an administrator."
        return
      end

      @stats = {
        total_resumes: current_user.resumes_in_current_tenant.count,
        processed_resumes: current_user.resumes_in_current_tenant.where(processing_status: 'completed').count,
        total_job_descriptions: current_user.job_descriptions_in_current_tenant.count,
        successful_processings: current_user.resumes_in_current_tenant.where(processing_status: 'completed').count
      }
    rescue ActiveRecord::StatementInvalid => e
      # Handle database errors gracefully
      Rails.logger.error "Database error in dashboard: #{e.message}"
      @stats = {
        total_resumes: 0,
        processed_resumes: 0,
        total_job_descriptions: 0,
        successful_processings: 0
      }
      flash[:alert] = "Unable to load dashboard data. Please try again or contact support if the problem persists."
    end
  end

  # Example method to test different toastr notifications
  def test_notifications
    case params[:type]
    when 'success'
      flash[:notice] = "Success! Operation completed successfully."
    when 'error'
      flash[:alert] = "Error! Something went wrong."
    when 'info'
      flash[:info] = "Info: Here's some helpful information."
    when 'warning'
      flash[:warning] = "Warning: Please check this carefully."
    end
    
    redirect_to root_path
  end

  private

  def table_exists?(table_name)
    ActiveRecord::Base.connection.table_exists?(table_name)
  rescue => e
    Rails.logger.error "Error checking table existence for #{table_name}: #{e.message}"
    false
  end

  def check_admin_subdomain_access!
    return unless on_admin_subdomain?
    
    # If user is on admin subdomain but not admin, redirect them
    unless current_user.admin?
      redirect_to root_url(host: 'localhost:3000'), alert: "Access denied. Admin privileges required."
    end
  end

  def on_admin_subdomain?
    host = request.host
    host_without_port = host.split(':').first
    parts = host_without_port.split('.')
    
    # In development, admin subdomain logic
    if Rails.env.development? && host_without_port == 'localhost'
      return false # Regular localhost access
    end
    
    subdomain = parts.length >= 2 ? parts.first : nil
    subdomain == 'all'
  end
end
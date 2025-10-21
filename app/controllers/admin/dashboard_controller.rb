class Admin::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :ensure_admin_subdomain!

  def index
    # Global stats across all tenants
    @stats = {
      total_tenants: Tenant.count,
      active_tenants: Tenant.active.count,
      total_users: User.count,
      total_data: calculate_global_data
    }

    @recent_tenants = Tenant.order(created_at: :desc).limit(5)
    @recent_users = User.order(created_at: :desc).limit(10)
  end

  private

  def ensure_admin!
    redirect_to new_user_session_path unless current_user&.admin?
  end

  def ensure_admin_subdomain!
    host = request.host
    # Extract subdomain from host
    host_without_port = host.split(':').first
    parts = host_without_port.split('.')
    
    subdomain = if Rails.env.development? && host_without_port == 'localhost'
      # In development, check if we're accessing from all.localhost
      nil # Allow localhost for development
    elsif parts.length >= 2
      parts.first
    else
      nil
    end
    
    # For development, allow localhost access for admin functionality
    # In production, ensure 'all' subdomain
    unless Rails.env.development? && host_without_port == 'localhost'
      redirect_to root_path unless subdomain == 'all'
    end
  end

  def calculate_global_data
    total_data = { 
      resumes: 0, 
      job_descriptions: 0, 
      processings: 0,
      successful_processings: 0,
      failed_processings: 0,
      processing_processings: 0
    }
    
    Tenant.active.find_each do |tenant|
      Apartment::Tenant.switch!(tenant.schema_name) do
        total_data[:resumes] += Resume.count rescue 0
        total_data[:job_descriptions] += JobDescription.count rescue 0  
        total_data[:processings] += ResumeProcessing.count rescue 0
        total_data[:successful_processings] += ResumeProcessing.where(status: 'completed').count rescue 0
        total_data[:failed_processings] += ResumeProcessing.where(status: 'failed').count rescue 0
        total_data[:processing_processings] += ResumeProcessing.where(status: 'processing').count rescue 0
      end
    end
    
    total_data
  rescue => e
    Rails.logger.error "Error calculating global data: #{e.message}"
    { resumes: 0, job_descriptions: 0, processings: 0, successful_processings: 0, failed_processings: 0, processing_processings: 0 }
  end
end

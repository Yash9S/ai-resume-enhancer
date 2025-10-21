class Admin::TenantsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :ensure_admin_subdomain!
  before_action :set_tenant, only: [:show, :edit, :update, :destroy, :activate, :pause, :stats]

  def index
    @tenants = Tenant.all.order(:name)
    @tenants = @tenants.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
  end

  def show
    @tenant_stats = calculate_tenant_stats
  end

  def new
    @tenant = Tenant.new
  end

  def create
    @tenant = Tenant.new(tenant_params)
    
    if @tenant.save
      redirect_to admin_tenant_path(@tenant), notice: 'Tenant was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @tenant.update(tenant_params)
      redirect_to admin_tenant_path(@tenant), notice: 'Tenant was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tenant.destroy
    redirect_to admin_tenants_path, notice: 'Tenant was successfully deleted.'
  end

  def activate
    begin
      @tenant.activate!
      redirect_to admin_tenants_path, notice: "Tenant '#{@tenant.name}' has been activated successfully."
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to activate tenant #{@tenant.id}: #{e.message}"
      redirect_to admin_tenants_path, alert: "Failed to activate tenant '#{@tenant.name}': #{e.message}"
    rescue => e
      Rails.logger.error "Unexpected error activating tenant #{@tenant.id}: #{e.message}"
      redirect_to admin_tenants_path, alert: "Failed to activate tenant '#{@tenant.name}': #{e.message}"
    end
  end

  def pause
    Rails.logger.info "Attempting to pause tenant #{@tenant.id} (#{@tenant.name})"
    
    if @tenant.pause!
      Rails.logger.info "Successfully paused tenant #{@tenant.id}"
      redirect_to admin_tenants_path, notice: "Tenant '#{@tenant.name}' paused successfully."
    else
      Rails.logger.error "Failed to pause tenant #{@tenant.id}: #{@tenant.errors.full_messages.join(', ')}"
      redirect_to admin_tenants_path, alert: "Failed to pause tenant: #{@tenant.errors.full_messages.join(', ')}"
    end
  rescue => e
    Rails.logger.error "Error pausing tenant #{@tenant.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    redirect_to admin_tenants_path, alert: "Error pausing tenant: #{e.message}"
  end

  def stats
    @tenant_stats = calculate_tenant_stats
    render json: @tenant_stats
  end

  private

  def set_tenant
    @tenant = Tenant.find_by(id: params[:id])
    unless @tenant
      redirect_to admin_tenants_path, alert: "Tenant not found."
      return
    end
  end

  def tenant_params
    params.require(:tenant).permit(:name, :subdomain, :schema_name, :status, :description)
  end

  def ensure_admin!
    redirect_to root_path unless current_user.admin?
  end

  def ensure_admin_subdomain!
    host = request.host
    # Extract subdomain from host
    host_without_port = host.split(':').first
    parts = host_without_port.split('.')
    
    subdomain = if Rails.env.development? && (host_without_port == 'localhost' || host.include?('localhost'))
      # In development, check if host starts with 'all.'
      if host.start_with?('all.')
        'all'
      else
        nil # Regular localhost access
      end
    elsif parts.length >= 2
      parts.first
    else
      nil
    end
    
    # For development, allow localhost access for admin functionality
    # In production, ensure 'all' subdomain
    unless Rails.env.development? && host_without_port == 'localhost' && !host.start_with?('all.')
      redirect_to root_path unless subdomain == 'all'
    end
  end

  def calculate_tenant_stats
    return {} unless @tenant&.schema_name

    stats = {}
    
    begin
      Apartment::Tenant.switch!(@tenant.schema_name) do
        stats = {
          resumes: Resume.count,
          job_descriptions: JobDescription.count,
          processings: ResumeProcessing.count,
          recent_resumes: Resume.recent.limit(5),
          successful_processings: ResumeProcessing.successful.count
        }
      end
    rescue => e
      Rails.logger.error "Error calculating stats for tenant #{@tenant.schema_name}: #{e.message}"
      stats = { error: e.message }
    end
    
    stats
  end
end

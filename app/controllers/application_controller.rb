class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # CSRF protection (skip for API controllers)
  protect_from_forgery with: :exception, unless: -> { request.format.json? }
  
  # Devise authentication
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_current_tenant # For future multitenancy

  # CanCanCan authorization
  # check_authorization unless: :skip_authorization?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:role])
    devise_parameter_sanitizer.permit(:account_update, keys: [:role])
  end
  
  def set_current_tenant
    # Ensure tenant switching is safe and doesn't crash the app
    begin
      # Let apartment elevator handle tenant switching automatically
      # Just ensure we're in a valid tenant context
      current_tenant = Apartment::Tenant.current
      
      # If we're in a tenant context, verify it exists
      if current_tenant && current_tenant != 'public'
        # Quick check if tenant database exists
        begin
          ActiveRecord::Base.connection.execute("SELECT 1")
        rescue => e
          Rails.logger.warn "Tenant #{current_tenant} database issue: #{e.message}"
          # Fall back to public schema if tenant has issues
          Apartment::Tenant.switch!('public')
        end
      end
    rescue => e
      Rails.logger.error "Tenant switching error: #{e.message}"
      # Ensure we're in a safe state
      begin
        Apartment::Tenant.switch!('public')
      rescue
        # If even public fails, let the request continue
        Rails.logger.error "Critical: Cannot switch to public schema"
      end
    end
  end

  # Redirect to sign in page after sign out
  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path
  end

  private

  def skip_authorization?
    devise_controller? || controller_name == 'rails_health'
  end
end

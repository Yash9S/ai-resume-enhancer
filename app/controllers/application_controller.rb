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
    # Future multitenancy support
    # Current.tenant = current_user&.tenant if current_user
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

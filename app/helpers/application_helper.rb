module ApplicationHelper
  def resume_status_class(status)
    case status.to_s
    when 'uploaded'
      'secondary'
    when 'processing'
      'warning'
    when 'processed'
      'success'
    when 'failed'
      'danger'
    else
      'light'
    end
  end

  def processing_status_class(status)
    case status.to_s
    when 'pending'
      'secondary'
    when 'processing'
      'warning'
    when 'completed'
      'success'
    when 'failed'
      'danger'
    else
      'light'
    end
  end

  def admin_subdomain?
    host = request.host
    host_without_port = host.split(':').first
    parts = host_without_port.split('.')
    
    # In development, check localhost patterns
    if Rails.env.development? && host_without_port == 'localhost'
      # Check if we're accessing via all.localhost:3000 in development
      return request.host.start_with?('all.')
    end
    
    # Extract subdomain for production
    subdomain = parts.length >= 2 ? parts.first : nil
    subdomain == 'all'
  end

  def current_subdomain
    host = request.host
    host_without_port = host.split(':').first
    parts = host_without_port.split('.')
    
    if Rails.env.development? && host_without_port == 'localhost'
      return 'localhost' 
    end
    
    parts.length >= 2 ? parts.first : nil
  end
end

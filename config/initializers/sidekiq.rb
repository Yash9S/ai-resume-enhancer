require 'sidekiq'

# Configure Sidekiq
Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV['REDIS_URL'] || 'redis://localhost:6379/0'
  }
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV['REDIS_URL'] || 'redis://localhost:6379/0'
  }
end

# Set Sidekiq as the Active Job adapter
Rails.application.config.active_job.queue_adapter = :sidekiq
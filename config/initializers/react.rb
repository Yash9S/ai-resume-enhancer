# config/initializers/react.rb
# Configure React for Rails 8 with Propshaft compatibility

# Configure react-rails properly for Rails 8
Rails.application.configure do
  # Configure react-rails with Rails 8 defaults
  config.react.variant = Rails.env.production? ? :production : :development
  config.react.addons = true
  config.react.server_renderer_pool_size ||= 1
  config.react.server_renderer_timeout ||= 20
  config.react.camelize_props = false
end

Rails.application.config.after_initialize do
  # Ensure React environment variables are set
  if defined?(React::Rails)
    ENV['NODE_ENV'] ||= Rails.env.production? ? 'production' : 'development'
  end
end
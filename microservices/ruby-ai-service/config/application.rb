require_relative 'boot'
require 'rails'
require 'active_model/railtie'
require 'action_controller/railtie'

Bundler.require(*Rails.groups)

module RubyAiService
  class Application < Rails::Application
    config.load_defaults 7.1
    config.api_only = true
    
    # CORS configuration for microservice communication
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*', 
          headers: :any, 
          methods: [:get, :post, :put, :patch, :delete, :options, :head]
      end
    end
    
    # Configure Ollama service URL
    config.after_initialize do
      ENV['OLLAMA_BASE_URL'] ||= 'http://host.docker.internal:11434'
    end
  end
end
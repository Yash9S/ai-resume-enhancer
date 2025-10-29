class HealthController < ApplicationController
  def index
    ollama_status = OllamaClient.new.available? ? 'available' : 'unavailable'
    
    render json: {
      status: 'healthy',
      service: 'ruby-ai-service',
      timestamp: Time.current.iso8601,
      version: '1.0.0',
      ollama_status: ollama_status
    }
  end
end
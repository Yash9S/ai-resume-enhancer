require 'net/http'
require 'json'
require 'timeout'

class OllamaClient
  def initialize
    @base_url = ENV.fetch('OLLAMA_BASE_URL', 'http://host.docker.internal:11434')
    @timeout = 60
  end

  def available?
    response = get('/api/tags')
    response.is_a?(Hash) && response['models']
  rescue => e
    Rails.logger.warn "Ollama not available: #{e.message}"
    false
  end

  def generate(model: 'llama3.2', prompt:, system: nil)
    payload = {
      model: model,
      prompt: prompt,
      system: system,
      stream: false,
      options: {
        temperature: 0.1,
        top_p: 0.9
      }
    }.compact

    response = post('/api/generate', payload)

    if response && response['response']
      {
        success: true,
        content: response['response'],
        model: model
      }
    else
      {
        success: false,
        error: 'No response from Ollama'
      }
    end
  rescue => e
    Rails.logger.error "Ollama generation failed: #{e.message}"
    {
      success: false,
      error: e.message
    }
  end

  private

  def post(path, payload)
    uri = URI("#{@base_url}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = @timeout

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    response = http.request(request)
    JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
  rescue => e
    Rails.logger.error "HTTP request failed: #{e.message}"
    nil
  end

  def get(path)
    uri = URI("#{@base_url}#{path}")
    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
  rescue => e
    Rails.logger.error "HTTP GET failed: #{e.message}"
    nil
  end
end
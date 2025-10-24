Rails.application.routes.draw do
  # Health check endpoint
  get '/health', to: 'health#index'
  
  # Extraction endpoints
  post '/extract/structured', to: 'extraction#structured'
  post '/extract/text', to: 'extraction#text'
end
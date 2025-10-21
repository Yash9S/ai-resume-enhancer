# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
Rails.application.config.assets.paths << Rails.root.join("app", "assets", "javascripts", "components")

# Precompile additional assets for React components
Rails.application.config.assets.precompile += %w[
  components.js
  components/*.js
  react_ujs.js
]

# Configure Sprockets for React components in development
if Rails.env.development?
  Rails.application.config.assets.debug = true
  Rails.application.config.assets.digest = false
end

# Configure Propshaft to work alongside Sprockets for React
Rails.application.configure do
  # Use Propshaft for main assets
  config.assets.enabled = true
  
  # Add React component paths
  config.assets.paths << Rails.root.join("app/assets/javascripts/components")
  config.assets.paths << Rails.root.join("app/assets/javascripts")
end

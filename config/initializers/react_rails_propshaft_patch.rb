# config/initializers/react_rails_propshaft_patch.rb
# Simplified patch for react-rails + Rails 8 + Propshaft compatibility

# Remove problematic react-rails initializers
if defined?(React::Rails::Railtie)
  React::Rails::Railtie.initializers.delete_if { |init| 
    init.name.to_s.include?('react_rails') 
  }
end
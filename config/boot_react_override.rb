# config/boot_react_override.rb
# Override react-rails before it loads to prevent Propshaft conflicts

# Create a fake React::Rails module to prevent the gem from loading problematic code
module React
  module Rails
    class Railtie < ::Rails::Railtie
      # Empty railtie - prevents react-rails gem railtie from loading
    end
    
    class ComponentMount
      def self.setup!(*)
        # Do nothing
      end
      
      def self.variant
        :development
      end
    end
    
    module ComponentHelper
      def react_component(name, props = {}, options = {})
        content_tag(:div, "", 
          data: { 
            react_component: name, 
            react_props: props.to_json 
          }.merge(options.fetch(:data, {})),
          class: "react-component #{options[:class]}".strip
        )
      end
    end
    
    COMPONENT_LOOKUP_PATH = Rails.root.join("app", "assets", "javascripts", "components")
  end
end

# Include the helper in ActionView
ActionView::Base.include(React::Rails::ComponentHelper) if defined?(ActionView::Base)
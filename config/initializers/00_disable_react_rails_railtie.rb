# config/initializers/00_disable_react_rails_railtie.rb
# This file loads early (00_) to disable problematic react-rails railtie before it loads

# Prevent react-rails from accessing sprockets env version by stubbing the methods
Rails.application.config.before_initialize do
  # Override Propshaft::Assembly to have version methods that react-rails expects
  if defined?(Propshaft::Assembly)
    Propshaft::Assembly.class_eval do
      attr_accessor :version
      
      def initialize(*args)
        super
        @version = "1.0"
      end
      
      # Stub all methods that react-rails might try to call
      def register_engine(*)
        # Do nothing
      end
      
      def register_mime_type(*)
        # Do nothing  
      end
      
      def register_transformer(*)
        # Do nothing
      end
      
      def register_preprocessor(*)
        # Do nothing
      end
      
      def register_postprocessor(*)
        # Do nothing
      end
    end
  end
end
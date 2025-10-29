# Disable apartment automatic migrations and seeding
# This prevents apartment from running migrations and seeds automatically during Rails startup

Rails.application.config.after_initialize do
  # Disable apartment rake task enhancements that cause automatic migrations
  if defined?(Apartment::RakeTaskEnhancer)
    Apartment::RakeTaskEnhancer.class_eval do
      def self.enhance_after_task(task_name)
        # Do nothing - disable automatic apartment migrations and seeding
        Rails.logger.info "Apartment migrations/seeding disabled for task: #{task_name}"
      end
    end
  end
  
  # Disable apartment migrator
  if defined?(Apartment::Migrator)
    Apartment::Migrator.class_eval do
      def self.migrate(*args)
        Rails.logger.info "Apartment migrations disabled - skipping migrate"
        return
      end
    end
  end
  
  # Disable apartment seeding
  if defined?(Apartment::Adapters::AbstractAdapter)
    Apartment::Adapters::AbstractAdapter.class_eval do
      def seed_data
        Rails.logger.info "Apartment seeding disabled - skipping seed_data"
        return
      end
    end
  end
end

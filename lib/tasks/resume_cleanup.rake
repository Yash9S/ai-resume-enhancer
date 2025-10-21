namespace :resumes do
  desc "Clean up stuck resume processing jobs"
  task cleanup_stuck: :environment do
    puts "🧹 Starting cleanup of stuck resume processing jobs..."
    CleanupStuckJobsJob.perform_now
    puts "✅ Cleanup completed!"
  end
  
  desc "Reset all processing resumes to pending (emergency reset)"
  task reset_all_processing: :environment do
    puts "⚠️  Emergency reset: Converting all 'processing' resumes to 'pending'"
    
    total_reset = 0
    
    Apartment::Tenant.each do |tenant|
      begin
        Apartment::Tenant.switch(tenant) do
          count = Resume.where(processing_status: 'processing')
                        .update_all(
                          processing_status: 'pending',
                          processing_error: 'Manual reset - retry processing',
                          processing_started_at: nil
                        )
          
          if count > 0
            puts "  - Tenant '#{tenant}': Reset #{count} resumes"
            total_reset += count
          end
        end
      rescue => e
        puts "  - Error in tenant '#{tenant}': #{e.message}"
      end
    end
    
    puts "✅ Total resumes reset: #{total_reset}"
  end
  
  desc "Show processing status summary"
  task status: :environment do
    puts "📊 Resume Processing Status Summary"
    puts "=" * 50
    
    Apartment::Tenant.each do |tenant|
      begin
        Apartment::Tenant.switch(tenant) do
          counts = Resume.group(:processing_status).count
          total = Resume.count
          
          if total > 0
            puts "\nTenant: #{tenant}"
            puts "  Total resumes: #{total}"
            counts.each do |status, count|
              percentage = (count.to_f / total * 100).round(1)
              puts "  #{status.capitalize}: #{count} (#{percentage}%)"
            end
            
            # Show any stuck processing jobs
            stuck = Resume.where(processing_status: 'processing')
                         .where('processing_started_at < ?', 3.minutes.ago)
                         .count
            
            if stuck > 0
              puts "  ⚠️  Stuck processing: #{stuck}"
            end
          end
        end
      rescue => e
        puts "\nTenant '#{tenant}': Error - #{e.message}"
      end
    end
  end
end
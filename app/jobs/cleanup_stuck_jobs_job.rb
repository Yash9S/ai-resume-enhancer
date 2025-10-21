class CleanupStuckJobsJob < ApplicationJob
  queue_as :low_priority
  
  # Run this job every few minutes to clean up stuck processing
  def perform
    Rails.logger.info "🧹 Cleaning up stuck resume processing jobs"
    
    stuck_count = 0
    
    # Process each tenant's resumes
    Apartment::Tenant.each do |tenant|
      begin
        Apartment::Tenant.switch(tenant) do
          # Find resumes that have been processing too long
          Resume.where(processing_status: 'processing')
                .where('processing_started_at < ?', 3.minutes.ago)
                .find_each do |resume|
            
            Rails.logger.warn "⏰ Found stuck resume #{resume.id} in tenant #{tenant}"
            
            # Reset to pending so it can be retried
            resume.update!(
              processing_status: 'pending',
              processing_error: 'Processing timeout - automatically reset',
              processing_started_at: nil
            )
            
            stuck_count += 1
          end
        end
      rescue => e
        Rails.logger.error "Failed to clean stuck jobs in tenant #{tenant}: #{e.message}"
      end
    end
    
    if stuck_count > 0
      Rails.logger.info "✅ Reset #{stuck_count} stuck processing jobs"
    else
      Rails.logger.debug "No stuck jobs found"
    end
  end
end
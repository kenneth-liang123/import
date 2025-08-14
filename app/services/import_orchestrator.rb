# frozen_string_literal: true

class ImportOrchestrator
  class << self
    # Import dailies from a CSV file (local or S3)
    def import_dailies(file_path, options = {})
      job_id = ImportDailiesJob.perform_async(file_path, options)
      
      Rails.logger.info "Enqueued ImportDailiesJob with ID: #{job_id}"
      
      {
        job_id: job_id,
        job_class: 'ImportDailiesJob',
        file_path: file_path,
        status: 'enqueued',
        options: options
      }
    end

    # Import daily health pillar relationships from a CSV file (local or S3)
    def import_daily_health_pillars(file_path, options = {})
      job_id = ImportDailyHealthPillarsJob.perform_async(file_path, options)
      
      Rails.logger.info "Enqueued ImportDailyHealthPillarsJob with ID: #{job_id}"
      
      {
        job_id: job_id,
        job_class: 'ImportDailyHealthPillarsJob',
        file_path: file_path,
        status: 'enqueued',
        options: options
      }
    end

    # Import both dailies and their health pillar relationships in sequence
    def import_full_dataset(dailies_file_path, pillars_file_path, options = {})
      # First import the dailies
      dailies_job = ImportDailiesJob.perform_async(dailies_file_path, options)
      
      # Then import the health pillar relationships (with a delay to ensure dailies are imported first)
      pillars_job = ImportDailyHealthPillarsJob.perform_in(
        options[:delay_seconds] || 30, # Wait 30 seconds by default
        pillars_file_path,
        options
      )
      
      Rails.logger.info "Enqueued sequential import jobs: #{dailies_job} -> #{pillars_job}"
      
      {
        dailies_job_id: dailies_job,
        pillars_job_id: pillars_job,
        status: 'enqueued',
        sequence: 'dailies_first_then_pillars'
      }
    end

    # Batch import multiple files
    def batch_import_dailies(file_paths, options = {})
      job_ids = []
      
      file_paths.each_with_index do |file_path, index|
        # Stagger the jobs to avoid overwhelming the system
        delay = (options[:stagger_seconds] || 5) * index
        
        job_id = if delay > 0
          ImportDailiesJob.perform_in(delay, file_path, options)
        else
          ImportDailiesJob.perform_async(file_path, options)
        end
        
        job_ids << job_id
      end
      
      Rails.logger.info "Enqueued #{job_ids.size} batch import jobs"
      
      {
        job_ids: job_ids,
        job_class: 'ImportDailiesJob',
        file_count: file_paths.size,
        status: 'enqueued'
      }
    end

    # Check the status of a job
    def job_status(job_id)
      require 'sidekiq/api'
      
      # Check if job is still queued
      queued_job = Sidekiq::Queue.new.find_job(job_id)
      return { status: 'queued', job_id: job_id } if queued_job

      # Check if job is currently processing
      working_job = Sidekiq::Workers.new.find { |process_id, thread_id, work| work['payload']['jid'] == job_id }
      return { status: 'processing', job_id: job_id } if working_job

      # Check if job failed
      retry_set = Sidekiq::RetrySet.new
      failed_job = retry_set.find { |job| job.jid == job_id }
      return { status: 'retrying', job_id: job_id, attempts: failed_job.retry_count } if failed_job

      # Check dead jobs
      dead_set = Sidekiq::DeadSet.new
      dead_job = dead_set.find { |job| job.jid == job_id }
      return { status: 'failed', job_id: job_id } if dead_job

      # Job completed (not found in any queue)
      { status: 'completed', job_id: job_id }
    end

    # Get statistics for all import jobs
    def import_stats
      require 'sidekiq/api'
      
      stats = Sidekiq::Stats.new
      queue = Sidekiq::Queue.new('default')
      
      # Count import jobs specifically
      import_jobs_queued = queue.select do |job|
        job.klass.in?(['ImportDailiesJob', 'ImportDailyHealthPillarsJob'])
      end

      {
        total_enqueued: stats.enqueued,
        total_processed: stats.processed,
        total_failed: stats.failed,
        import_jobs_queued: import_jobs_queued.size,
        workers_busy: stats.workers_size,
        queue_latency: queue.latency
      }
    end

    # Clear all failed import jobs
    def clear_failed_import_jobs
      require 'sidekiq/api'
      
      dead_set = Sidekiq::DeadSet.new
      retry_set = Sidekiq::RetrySet.new
      
      import_job_classes = ['ImportDailiesJob', 'ImportDailyHealthPillarsJob']
      
      # Clear dead jobs
      dead_count = 0
      dead_set.each do |job|
        if job.klass.in?(import_job_classes)
          job.delete
          dead_count += 1
        end
      end

      # Clear retry jobs
      retry_count = 0
      retry_set.each do |job|
        if job.klass.in?(import_job_classes)
          job.delete
          retry_count += 1
        end
      end

      Rails.logger.info "Cleared #{dead_count} dead and #{retry_count} retry import jobs"
      
      {
        dead_jobs_cleared: dead_count,
        retry_jobs_cleared: retry_count,
        total_cleared: dead_count + retry_count
      }
    end

    # Validate file before importing
    def validate_import_file(file_path, import_type)
      errors = []
      
      # Check file existence
      if file_path.start_with?('s3://')
        # For S3 files, we'll validate during job execution
        Rails.logger.info "S3 file validation will occur during job execution: #{file_path}"
      else
        errors << "File not found: #{file_path}" unless File.exist?(file_path)
        errors << "File not readable: #{file_path}" unless File.readable?(file_path)
      end

      # Validate import type
      valid_types = ['dailies', 'daily_health_pillars']
      errors << "Invalid import type: #{import_type}" unless import_type.in?(valid_types)

      {
        valid: errors.empty?,
        errors: errors,
        file_path: file_path,
        import_type: import_type
      }
    end
  end
end

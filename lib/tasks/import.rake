# frozen_string_literal: true

namespace :import do
  # BACKGROUND JOB TASKS (RECOMMENDED)
  # =====================================
  
  desc "Import dailies from CSV file using Sidekiq (local or S3)"
  task :dailies, [:file_path] => :environment do |t, args|
    file_path = args[:file_path]
    
    if file_path.blank?
      puts "Usage: rails import:dailies[/path/to/file.csv]"
      puts "   or: rails import:dailies[s3://bucket/path/file.csv]"
      exit 1
    end

    puts "🚀 Enqueuing import job for dailies..."
    puts "File: #{file_path}"
    
    result = ImportOrchestrator.import_dailies(file_path)
    
    puts "✅ Job enqueued successfully!"
    puts "Job ID: #{result[:job_id]}"
    puts "Monitor at: http://localhost:3000/sidekiq"
  end

  desc "Import daily health pillar relationships from CSV file using Sidekiq (local or S3)"
  task :daily_health_pillars, [:file_path] => :environment do |t, args|
    file_path = args[:file_path]
    
    if file_path.blank?
      puts "Usage: rails import:daily_health_pillars[/path/to/file.csv]"
      puts "   or: rails import:daily_health_pillars[s3://bucket/path/file.csv]"
      exit 1
    end

    puts "🚀 Enqueuing import job for daily health pillars..."
    puts "File: #{file_path}"
    
    result = ImportOrchestrator.import_daily_health_pillars(file_path)
    
    puts "✅ Job enqueued successfully!"
    puts "Job ID: #{result[:job_id]}"
    puts "Monitor at: http://localhost:3000/sidekiq"
  end

  desc "Import full dataset (dailies + health pillars) in sequence using Sidekiq"
  task :full_dataset, [:dailies_file, :pillars_file] => :environment do |t, args|
    dailies_file = args[:dailies_file]
    pillars_file = args[:pillars_file]
    
    if dailies_file.blank? || pillars_file.blank?
      puts "Usage: rails import:full_dataset[/path/to/dailies.csv,/path/to/pillars.csv]"
      puts "   or: rails import:full_dataset[s3://bucket/dailies.csv,s3://bucket/pillars.csv]"
      exit 1
    end

    puts "🚀 Enqueuing sequential import jobs..."
    puts "Dailies file: #{dailies_file}"
    puts "Pillars file: #{pillars_file}"
    
    result = ImportOrchestrator.import_full_dataset(dailies_file, pillars_file)
    
    puts "✅ Jobs enqueued successfully!"
    puts "Dailies Job ID: #{result[:dailies_job_id]}"
    puts "Pillars Job ID: #{result[:pillars_job_id]}"
    puts "Monitor at: http://localhost:3000/sidekiq"
  end

  desc "Check status of an import job"
  task :status, [:job_id] => :environment do |t, args|
    job_id = args[:job_id]
    
    if job_id.blank?
      puts "Usage: rails import:status[job_id]"
      exit 1
    end

    puts "🔍 Checking status for job: #{job_id}"
    
    status = ImportOrchestrator.job_status(job_id)
    
    puts "Status: #{status[:status].upcase}"
    puts "Job ID: #{status[:job_id]}"
    puts "Attempts: #{status[:attempts]}" if status[:attempts]
  end

  desc "Show import statistics"
  task :stats => :environment do
    puts "📊 Import Job Statistics"
    puts "=" * 40
    
    stats = ImportOrchestrator.import_stats
    
    puts "Total Jobs Enqueued: #{stats[:total_enqueued]}"
    puts "Total Jobs Processed: #{stats[:total_processed]}"
    puts "Total Jobs Failed: #{stats[:total_failed]}"
    puts "Import Jobs in Queue: #{stats[:import_jobs_queued]}"
    puts "Workers Busy: #{stats[:workers_busy]}"
    puts "Queue Latency: #{stats[:queue_latency].round(2)}s"
    
    puts "\n💡 Monitor detailed stats at: http://localhost:3000/sidekiq"
  end

  desc "Clear all failed import jobs"
  task :clear_failed => :environment do
    puts "🧹 Clearing failed import jobs..."
    
    result = ImportOrchestrator.clear_failed_import_jobs
    
    puts "✅ Cleanup completed!"
    puts "Dead jobs cleared: #{result[:dead_jobs_cleared]}"
    puts "Retry jobs cleared: #{result[:retry_jobs_cleared]}"
    puts "Total cleared: #{result[:total_cleared]}"
  end

  # LEGACY SYNCHRONOUS TASKS (FOR SMALL FILES OR TESTING)
  # ======================================================
  
  desc "LEGACY: Import dailies data synchronously from CSV file"
  task :dailies_sync, [ :filepath ] => :environment do |task, args|
    filepath = args[:filepath] || raise("Please provide filepath: rake import:dailies_sync[path/to/file.csv]")

    unless File.exist?(filepath)
      puts "Error: File not found at #{filepath}"
      exit 1
    end

    puts "Starting dailies import from #{filepath}..."
    importer = Importer::Dailies.new(filepath)
    importer.import

    if importer.errors.any?
      puts "Import completed with errors:"
      importer.errors.each { |error| puts "  - #{error}" }
    else
      puts "Import completed successfully!"
    end
  end

  desc "LEGACY: Import daily health pillars data synchronously from CSV file"
  task :daily_health_pillars_sync, [ :filepath ] => :environment do |task, args|
    filepath = args[:filepath] || raise("Please provide filepath: rake import:daily_health_pillars_sync[path/to/file.csv]")

    unless File.exist?(filepath)
      puts "Error: File not found at #{filepath}"
      exit 1
    end

    puts "Starting daily health pillars import from #{filepath}..."
    importer = Importer::DailyHealthPillars.new(filepath)
    importer.import

    if importer.errors.any?
      puts "Import completed with errors:"
      importer.errors.each { |error| puts "  - #{error}" }
    else
      puts "Import completed successfully!"
    end
  end

  desc "LEGACY: Download file from S3 and import dailies data synchronously"
  task :dailies_from_s3_sync, [ :filename, :bucket ] => :environment do |task, args|
    filename = args[:filename] || raise("Please provide filename: rake import:dailies_from_s3_sync[filename.csv]")
    bucket = args[:bucket] || ENV["AWS_S3_IMPORTERS_BUCKET_NAME"] || "unleashh"

    puts "Downloading #{filename} from S3 bucket #{bucket}..."
    downloader = S3FileDownloader.new(filename, bucket)
    filepath = downloader.download

    puts "Starting dailies import from downloaded file..."
    importer = Importer::Dailies.new(filepath)
    importer.import

    if importer.errors.any?
      puts "Import completed with errors:"
      importer.errors.each { |error| puts "  - #{error}" }
    else
      puts "Import completed successfully!"
    end

    # Clean up downloaded file
    File.delete(filepath) if File.exist?(filepath)
    puts "Cleaned up temporary file"
  end

  desc "LEGACY: Test mode import (dry run) for dailies"
  task :test_dailies, [ :filepath ] => :environment do |task, args|
    filepath = args[:filepath] || raise("Please provide filepath: rake import:test_dailies[path/to/file.csv]")

    unless File.exist?(filepath)
      puts "Error: File not found at #{filepath}"
      exit 1
    end

    puts "Starting TEST MODE dailies import from #{filepath}..."
    importer = Importer::Dailies.new(filepath, test_mode: true)
    importer.import

    if importer.errors.any?
      puts "Test import completed with errors:"
      importer.errors.each { |error| puts "  - #{error}" }
    else
      puts "Test import completed successfully! (No data was actually saved)"
    end
  end

  # UTILITY TASKS
  # =============
  
  desc "Validate a file before importing"
  task :validate, [:file_path, :import_type] => :environment do |t, args|
    file_path = args[:file_path]
    import_type = args[:import_type]
    
    if file_path.blank? || import_type.blank?
      puts "Usage: rails import:validate[/path/to/file.csv,dailies]"
      puts "   or: rails import:validate[s3://bucket/file.csv,daily_health_pillars]"
      puts ""
      puts "Import types: dailies, daily_health_pillars"
      exit 1
    end

    puts "🔍 Validating file for import..."
    puts "File: #{file_path}"
    puts "Type: #{import_type}"
    
    result = ImportOrchestrator.validate_import_file(file_path, import_type)
    
    if result[:valid]
      puts "✅ File validation passed!"
    else
      puts "❌ File validation failed:"
      result[:errors].each { |error| puts "  - #{error}" }
      exit 1
    end
  end

  desc "Show usage examples and help"
  task :help => :environment do
    puts "📚 Import Task Usage Examples"
    puts "=" * 50
    puts ""
    puts "🚀 BACKGROUND JOBS (RECOMMENDED):"
    puts "=" * 35
    puts ""
    puts "1. Import dailies from local file:"
    puts "   rails import:dailies[/path/to/dailies.csv]"
    puts ""
    puts "2. Import dailies from S3:"
    puts "   rails import:dailies[s3://your-bucket/dailies.csv]"
    puts ""
    puts "3. Import health pillar relationships:"
    puts "   rails import:daily_health_pillars[/path/to/pillars.csv]"
    puts ""
    puts "4. Import full dataset in sequence:"
    puts "   rails import:full_dataset[dailies.csv,pillars.csv]"
    puts ""
    puts "5. Check job status:"
    puts "   rails import:status[job_id_here]"
    puts ""
    puts "6. View statistics:"
    puts "   rails import:stats"
    puts ""
    puts "7. Clear failed jobs:"
    puts "   rails import:clear_failed"
    puts ""
    puts "8. Validate file before import:"
    puts "   rails import:validate[file.csv,dailies]"
    puts ""
    puts "📊 LEGACY SYNC TASKS (for small files):"
    puts "=" * 40
    puts ""
    puts "9. Synchronous dailies import:"
    puts "   rails import:dailies_sync[/path/to/file.csv]"
    puts ""
    puts "10. Synchronous health pillars import:"
    puts "    rails import:daily_health_pillars_sync[/path/to/file.csv]"
    puts ""
    puts "11. Test mode (dry run):"
    puts "    rails import:test_dailies[/path/to/file.csv]"
    puts ""
    puts "🌐 Monitor background jobs at: http://localhost:3000/sidekiq"
    puts ""
    puts "💡 TIP: Use background jobs for large files or production imports!"
  end
end

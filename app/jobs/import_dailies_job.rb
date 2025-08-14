# frozen_string_literal: true

class ImportDailiesJob
  include Sidekiq::Job
  
  # Retry failed jobs up to 3 times with exponential backoff
  sidekiq_options retry: 3, backtrace: true
  
  # Custom retry logic with exponential backoff
  sidekiq_retry_in do |count, exception|
    10 * (count + 1) # 10, 20, 30 seconds
  end

  def perform(file_path, options = {})
    @file_path = file_path
    @options = options.with_indifferent_access
    @start_time = Time.current
    
    log_job_start
    
    # Initialize the importer service
    importer = Importer::Dailies.new(@file_path, test_mode_enabled: @options[:test_mode] || false)
    
    # Perform the import
    result = perform_import(importer)
    
    log_job_completion(result)
    
    # Return job result for monitoring
    {
      status: 'completed',
      file_path: @file_path,
      processed_rows: result[:processed_rows],
      errors: result[:errors],
      duration: Time.current - @start_time
    }
    
  rescue => error
    log_job_error(error)
    raise # Re-raise to trigger retry logic
  end

  private

  def perform_import(importer)
    # Download file if it's an S3 path
    local_file_path = download_file_if_needed
    
    # Validate file exists and is readable
    validate_file_access(local_file_path)
    
    # Parse CSV and validate headers
    csv_data = parse_and_validate_csv(local_file_path, importer)
    
    # Process the import with progress tracking
    process_csv_data(importer, csv_data)
    
  ensure
    # Cleanup temporary files
    cleanup_temp_file(local_file_path) if local_file_path != @file_path
  end

  def download_file_if_needed
    if @file_path.start_with?('s3://')
      Rails.logger.info "Downloading file from S3: #{@file_path}"
      downloader = S3FileDownloader.new
      temp_file = downloader.download(@file_path)
      temp_file.path
    else
      @file_path
    end
  end

  def validate_file_access(file_path)
    unless File.exist?(file_path)
      raise ArgumentError, "File not found: #{file_path}"
    end
    
    unless File.readable?(file_path)
      raise ArgumentError, "File not readable: #{file_path}"
    end
  end

  def parse_and_validate_csv(file_path, importer)
    csv_data = CSV.read(file_path, headers: true)
    
    # Validate required headers using our own method
    actual_headers = csv_data.headers || []
    missing_headers = Importer::Dailies::REQUIRED_HEADERS - actual_headers
    if missing_headers.any?
      raise ArgumentError, "Missing required CSV headers: #{missing_headers.join(', ')}"
    end
    
    Rails.logger.info "CSV validation passed. Found #{csv_data.size} rows to process"
    csv_data
  end

  def process_csv_data(importer, csv_data)
    total_rows = csv_data.size
    processed_rows = 0
    errors = []
    
    # Process in batches for better memory management
    csv_data.each_slice(100).with_index do |batch, batch_index|
      ActiveRecord::Base.transaction do
        batch.each_with_index do |row, row_index|
          begin
            # Import individual row
            importer.import_single_daily(row)
            processed_rows += 1
            
            # Report progress every 100 rows
            if (processed_rows % 100).zero?
              progress_percentage = (processed_rows.to_f / total_rows * 100).round(2)
              Rails.logger.info "Progress: #{processed_rows}/#{total_rows} (#{progress_percentage}%)"
            end
            
          rescue => row_error
            error_message = "Row #{batch_index * 100 + row_index + 1}: #{row_error.message}"
            errors << error_message
            Rails.logger.warn error_message
            
            # Stop processing if too many errors
            if errors.size > (@options[:max_errors] || 100)
              raise "Too many errors encountered (#{errors.size}). Stopping import."
            end
          end
        end
      end
    end
    
    {
      processed_rows: processed_rows,
      errors: errors,
      total_rows: total_rows
    }
  end

  def setup_progress_tracking(importer)
    # Add progress callback to importer if it supports it
    if importer.respond_to?(:on_progress)
      importer.on_progress do |current, total|
        update_job_progress(current, total)
      end
    end
  end

  def update_job_progress(current, total)
    # Update Sidekiq job progress for web UI monitoring
    at(current, "Processing #{current}/#{total} rows")
  end

  def cleanup_temp_file(file_path)
    if file_path && File.exist?(file_path) && file_path.include?('/tmp/')
      File.delete(file_path)
      Rails.logger.info "Cleaned up temporary file: #{file_path}"
    end
  rescue => error
    Rails.logger.warn "Failed to cleanup temp file #{file_path}: #{error.message}"
  end

  def log_job_start
    Rails.logger.info "Starting ImportDailiesJob for file: #{@file_path}"
    Rails.logger.info "Job options: #{@options.inspect}"
  end

  def log_job_completion(result)
    duration = Time.current - @start_time
    Rails.logger.info "ImportDailiesJob completed successfully"
    Rails.logger.info "Processed: #{result[:processed_rows]} rows in #{duration.round(2)}s"
    Rails.logger.info "Errors: #{result[:errors].size}" if result[:errors].any?
  end

  def log_job_error(error)
    duration = Time.current - @start_time
    Rails.logger.error "ImportDailiesJob failed after #{duration.round(2)}s"
    Rails.logger.error "Error: #{error.class} - #{error.message}"
    Rails.logger.error error.backtrace.first(10).join("\n") if error.backtrace
  end
end

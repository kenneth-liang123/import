# frozen_string_literal: true

class ImportDailyHealthPillarsJob
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
    importer = Importer::DailyHealthPillars.new(@file_path, test_mode_enabled: @options[:test_mode] || false)
    
    # Perform the import
    result = perform_import(importer)
    
    log_job_completion(result)
    
    # Return job result for monitoring
    {
      status: 'completed',
      file_path: @file_path,
      processed_rows: result[:processed_rows],
      relationships_created: result[:relationships_created],
      missing_dailies: result[:missing_dailies],
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
      
      # Parse S3 path: s3://bucket/key
      s3_uri = URI.parse(@file_path)
      bucket = s3_uri.host
      filename = s3_uri.path[1..]  # Remove leading slash
      
      downloader = S3FileDownloader.new(filename, bucket)
      temp_file_path = downloader.download
      temp_file_path
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
    
    # Validate required headers (daily_name is required)
    unless csv_data.headers.include?('daily_name')
      raise ArgumentError, "Missing required CSV header: daily_name"
    end
    
    # Discover available health pillar columns dynamically
    health_pillar_headers = importer.discover_health_pillar_headers(csv_data.headers)
    
    if health_pillar_headers.empty?
      raise ArgumentError, "No health pillar columns found in CSV"
    end
    
    Rails.logger.info "CSV validation passed. Found #{csv_data.size} rows with #{health_pillar_headers.size} health pillars"
    csv_data
  end

  def process_csv_data(importer, csv_data)
    total_rows = csv_data.size
    processed_rows = 0
    relationships_created = 0
    errors = []
    missing_dailies = []
    
    # Pre-fetch all health pillars for efficiency
    health_pillars = HealthPillar.all.index_by(&:name)
    
    # Process in batches for better memory management
    csv_data.each_slice(50).with_index do |batch, batch_index|
      ActiveRecord::Base.transaction do
        batch.each_with_index do |row, row_index|
          begin
            # Process individual row
            row_result = process_single_row(row, health_pillars, importer)
            
            if row_result[:daily_found]
              relationships_created += row_result[:relationships_count]
              processed_rows += 1
            else
              missing_dailies << row['daily_name']&.strip
            end
            
            # Report progress every 50 rows
            current_row = batch_index * 50 + row_index + 1
            if (current_row % 50).zero?
              progress_percentage = (current_row.to_f / total_rows * 100).round(2)
              Rails.logger.info "Progress: #{current_row}/#{total_rows} (#{progress_percentage}%)"
              
              # Update job progress for monitoring
              update_job_progress(current_row, total_rows)
            end
            
          rescue => row_error
            error_message = "Row #{batch_index * 50 + row_index + 1}: #{row_error.message}"
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
    
    # Log missing dailies summary
    if missing_dailies.any?
      unique_missing = missing_dailies.uniq
      Rails.logger.warn "Missing dailies (#{unique_missing.size}): #{unique_missing.first(10).join(', ')}"
      Rails.logger.warn "... and #{unique_missing.size - 10} more" if unique_missing.size > 10
    end
    
    {
      processed_rows: processed_rows,
      relationships_created: relationships_created,
      errors: errors,
      missing_dailies: missing_dailies.uniq,
      total_rows: total_rows
    }
  end

  def process_single_row(row, health_pillars, importer)
    daily_name = row['daily_name']&.strip
    return { daily_found: false, relationships_count: 0 } if daily_name.blank?
    
    # Find the daily record
    daily = Daily.find_by(name: daily_name)
    return { daily_found: false, relationships_count: 0 } unless daily
    
    # Skip database modifications in test mode
    return { daily_found: true, relationships_count: 0 } if @options[:test_mode]
    
    # Clear existing relationships for this daily (idempotent)
    daily.daily_health_pillars.delete_all if @options[:clear_existing] != false
    
    relationships_count = 0
    
    # Process each health pillar column
    importer.discover_health_pillar_headers(row.headers).each do |header|
      pillar_name = header.gsub('health_pillar_', '').strip
      health_pillar = health_pillars[pillar_name]
      
      if health_pillar && row[header].to_s.strip.downcase == 'true'
        # Create the relationship
        daily.daily_health_pillars.find_or_create_by(health_pillar: health_pillar)
        relationships_count += 1
      end
    end
    
    { daily_found: true, relationships_count: relationships_count }
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
    at(current, "Processing #{current}/#{total} relationships")
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
    Rails.logger.info "Starting ImportDailyHealthPillarsJob for file: #{@file_path}"
    Rails.logger.info "Job options: #{@options.inspect}"
  end

  def log_job_completion(result)
    duration = Time.current - @start_time
    Rails.logger.info "ImportDailyHealthPillarsJob completed successfully"
    Rails.logger.info "Processed: #{result[:processed_rows]} rows, #{result[:relationships_created]} relationships in #{duration.round(2)}s"
    Rails.logger.info "Missing dailies: #{result[:missing_dailies].size}" if result[:missing_dailies].any?
    Rails.logger.info "Errors: #{result[:errors].size}" if result[:errors].any?
  end

  def log_job_error(error)
    duration = Time.current - @start_time
    Rails.logger.error "ImportDailyHealthPillarsJob failed after #{duration.round(2)}s"
    Rails.logger.error "Error: #{error.class} - #{error.message}"
    Rails.logger.error error.backtrace.first(10).join("\n") if error.backtrace
  end
end

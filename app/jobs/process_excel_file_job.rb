class ProcessExcelFileJob
  include Sidekiq::Job

  sidekiq_options retry: 3, backtrace: true

  def perform(file_upload_id)
    file_upload = FileUpload.find(file_upload_id)
    
    begin
      file_upload.mark_as_processing!(jid)
      
      # Download the file to a temporary location
      temp_file = download_file(file_upload)
      
      # Convert Excel to CSV if needed
      csv_file_path = convert_to_csv(temp_file, file_upload)
      
      # Process based on file type and import behavior
      process_file(csv_file_path, file_upload)
      
      file_upload.mark_as_completed!
      
    rescue => e
      Rails.logger.error "ProcessExcelFileJob failed for FileUpload #{file_upload_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      file_upload.mark_as_failed!(e.message)
      raise e
    ensure
      # Cleanup temporary files
      cleanup_temp_files(temp_file, csv_file_path)
    end
  end

  private

  def download_file(file_upload)
    temp_file = Tempfile.new([file_upload.filename.gsub(/\.[^.]+$/, ''), file_upload.file_extension])
    temp_file.binmode
    
    file_upload.file.download do |chunk|
      temp_file.write(chunk)
    end
    
    temp_file.rewind
    temp_file
  end

  def convert_to_csv(temp_file, file_upload)
    if file_upload.csv_file?
      return temp_file.path
    end

    # Convert Excel to CSV
    csv_file = Tempfile.new([file_upload.filename.gsub(/\.[^.]+$/, ''), '.csv'])
    
    begin
      workbook = Roo::Spreadsheet.open(temp_file.path)
      sheet = workbook.sheet(0) # Use first sheet
      
      CSV.open(csv_file.path, 'w') do |csv|
        sheet.each_row_streaming do |row|
          csv << row.map(&:value)
        end
      end
      
      csv_file.path
    rescue => e
      csv_file.close
      csv_file.unlink
      raise "Failed to convert Excel file to CSV: #{e.message}"
    end
  end

  def process_file(csv_file_path, file_upload)
    case file_upload.file_type
    when 'dailies'
      process_dailies_file(csv_file_path, file_upload)
    when 'daily_health_pillars'
      process_daily_health_pillars_file(csv_file_path, file_upload)
    else
      raise "Unsupported file type: #{file_upload.file_type}"
    end
  end

  def process_dailies_file(csv_file_path, file_upload)
    options = build_job_options(file_upload)
    ImportDailiesJob.perform_async(csv_file_path, options)
  end

  def process_daily_health_pillars_file(csv_file_path, file_upload)
    options = build_job_options(file_upload)
    ImportDailyHealthPillarsJob.perform_async(csv_file_path, options)
  end

  def build_job_options(file_upload)
    {
      'user_email' => file_upload.user_email,
      'import_type' => file_upload.import_type,
      'file_upload_id' => file_upload.id,
      'test_mode' => false
    }
  end

  def cleanup_temp_files(*files)
    files.compact.each do |file|
      if file.respond_to?(:close)
        file.close
        file.unlink if file.respond_to?(:unlink)
      elsif file.is_a?(String) && File.exist?(file)
        File.unlink(file)
      end
    end
  end
end

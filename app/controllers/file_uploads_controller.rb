class FileUploadsController < ApplicationController
  before_action :set_file_upload, only: [:show, :retry, :status]

  def index
    @file_uploads = FileUpload.recent.limit(50)
    @new_file_upload = FileUpload.new
  end

  def create
    @new_file_upload = FileUpload.new(file_upload_params)
    @new_file_upload.status = 'pending'
    
    # Custom file validation
    if @new_file_upload.file.present?
      file_extension = File.extname(@new_file_upload.file.filename.to_s).downcase
      unless %w[.xlsx .xls .csv].include?(file_extension)
        @new_file_upload.errors.add(:file, 'must be an Excel (.xlsx, .xls) or CSV file')
      end
    end
    
    if @new_file_upload.errors.empty? && @new_file_upload.save
      # Enqueue the processing job
      job_id = ProcessExcelFileJob.perform_async(@new_file_upload.id)
      @new_file_upload.update!(job_id: job_id)
      
      redirect_to file_uploads_path, notice: 'File uploaded successfully and processing has begun.'
    else
      @file_uploads = FileUpload.recent.limit(50)
      render :index, status: :unprocessable_entity
    end
  end

  def show
    @file_upload = FileUpload.find(params[:id])
  end

  def retry
    if @file_upload.can_retry?
      @file_upload.update!(status: 'pending', error_message: nil)
      job_id = ProcessExcelFileJob.perform_async(@file_upload.id)
      @file_upload.update!(job_id: job_id)
      
      redirect_to @file_upload, notice: 'File processing has been retried.'
    else
      redirect_to @file_upload, alert: 'This file cannot be retried.'
    end
  end

  def status
    render json: {
      id: @file_upload.id,
      status: @file_upload.status,
      error_message: @file_upload.error_message,
      processed_at: @file_upload.processed_at,
      created_at: @file_upload.created_at
    }
  end

  private

  def set_file_upload
    @file_upload = FileUpload.find(params[:id])
  end

  def file_upload_params
    permitted = params.require(:file_upload).permit(:file, :file_type, :import_type, :user_email)
    
    # Extract filename from uploaded file
    if permitted[:file].present?
      permitted[:filename] = permitted[:file].original_filename
    end
    
    permitted
  end
end

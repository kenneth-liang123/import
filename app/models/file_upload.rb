class FileUpload < ApplicationRecord
  has_one_attached :file

  validates :filename, presence: true
  validates :file_type, presence: true, inclusion: { in: %w[dailies daily_health_pillars] }
  validates :import_type, presence: true, inclusion: { in: %w[import update] }
  validates :status, presence: true, inclusion: { in: %w[pending processing completed failed] }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_user, ->(email) { where(user_email: email) }

  def pending?
    status == 'pending'
  end

  def processing?
    status == 'processing'
  end

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def can_retry?
    failed?
  end

  def file_extension
    return nil unless filename
    File.extname(filename).downcase
  end

  def excel_file?
    %w[.xlsx .xls].include?(file_extension)
  end

  def csv_file?
    file_extension == '.csv'
  end

  def supported_file?
    excel_file? || csv_file?
  end

  def mark_as_processing!(job_id)
    update!(status: 'processing', job_id: job_id)
  end

  def mark_as_completed!
    update!(status: 'completed', processed_at: Time.current)
  end

  def mark_as_failed!(error_message)
    update!(status: 'failed', error_message: error_message, processed_at: Time.current)
  end
end

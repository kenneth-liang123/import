class S3FileDownloader
  DEFAULT_FILENAME = "default_import.csv".freeze
  DEFAULT_S3_BUCKET = (ENV["AWS_S3_IMPORTERS_BUCKET_NAME"] || "default-bucket").freeze

  attr_reader :filename, :bucket

  def initialize(filename = DEFAULT_FILENAME, bucket = DEFAULT_S3_BUCKET)
    @filename = filename
    @bucket = bucket
  end

  def download
    puts "Processing file..."
    download_file
    puts "File downloaded to #{file_path}"
    file_path
  end

  private

  def download_file
    aws_s3_object = s3_bucket.object(filename)
    aws_s3_object.get(response_target: file_path)
  end

  def s3_bucket
    aws_connection.bucket(bucket)
  end

  def aws_connection
    @aws_connection ||= Aws::S3::Resource.new
  end

  def file_path
    Rails.root.join("tmp", filename)
  end
end

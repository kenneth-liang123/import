require 'rails_helper'

RSpec.describe S3FileDownloader, type: :service do
  let(:filename) { 'test_file.csv' }
  let(:bucket_name) { 'test-bucket' }
  let(:downloader) { described_class.new(filename, bucket_name) }
  let(:mock_s3_resource) { instance_double(Aws::S3::Resource) }
  let(:mock_bucket) { instance_double(Aws::S3::Bucket) }
  let(:mock_object) { instance_double(Aws::S3::Object) }
  let(:expected_file_path) { Rails.root.join("tmp", filename) }

  before do
    allow(Aws::S3::Resource).to receive(:new).and_return(mock_s3_resource)
    allow(mock_s3_resource).to receive(:bucket).with(bucket_name).and_return(mock_bucket)
    allow(mock_bucket).to receive(:object).with(filename).and_return(mock_object)
  end

  describe '#initialize' do
    context 'with custom parameters' do
      it 'sets the filename and bucket' do
        expect(downloader.filename).to eq(filename)
        expect(downloader.bucket).to eq(bucket_name)
      end
    end

    context 'with default parameters' do
      let(:downloader) { described_class.new }

      it 'uses default values when environment variable is not set' do
        expect(downloader.bucket).to eq("default-bucket")
        expect(downloader.filename).to eq("default_import.csv")
      end
    end
  end

  describe '#download' do
    before do
      allow(mock_object).to receive(:get).with(response_target: expected_file_path)
      allow(downloader).to receive(:puts) # Suppress output in tests
    end

    it 'downloads the file from S3' do
      result = downloader.download

      expect(mock_object).to have_received(:get).with(response_target: expected_file_path)
      expect(result).to eq(expected_file_path)
    end

    it 'prints processing messages' do
      expect(downloader).to receive(:puts).with("Processing file...")
      expect(downloader).to receive(:puts).with("File downloaded to #{expected_file_path}")

      downloader.download
    end
  end

  describe '#file_path' do
    it 'returns the correct file path' do
      expect(downloader.send(:file_path)).to eq(expected_file_path)
    end
  end

  describe '#aws_connection' do
    it 'creates an AWS S3 Resource connection' do
      expect(Aws::S3::Resource).to receive(:new)
      downloader.send(:aws_connection)
    end

    it 'memoizes the connection' do
      connection1 = downloader.send(:aws_connection)
      connection2 = downloader.send(:aws_connection)
      expect(connection1).to be(connection2)
    end
  end

  describe 'error handling' do
    context 'when AWS raises an error' do
      before do
        allow(mock_object).to receive(:get).and_raise(Aws::S3::Errors::NoSuchKey.new(nil, 'File not found'))
      end

      it 'propagates the AWS error' do
        expect { downloader.download }.to raise_error(Aws::S3::Errors::NoSuchKey)
      end
    end
  end
end

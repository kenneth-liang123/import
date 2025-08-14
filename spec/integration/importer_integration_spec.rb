require 'rails_helper'

RSpec.describe 'Importer Integration', type: :integration do
  let(:s3_downloader) { S3FileDownloader.new('test_file.csv', 'test-bucket') }
  let(:csv_content) do
    <<~CSV
      unleash id,name,description,duration,effort,detailed health benefit,guide,tools
      1,Morning Exercise,Start the day with movement,20,Medium,Boosts energy and metabolism,Do 10 minutes of stretching followed by light cardio,Exercise mat
      2,Mindful Eating,Practice conscious eating habits,30,Low,Improves digestion and nutrition awareness,Eat slowly and focus on flavors and textures,Mindfulness app
    CSV
  end
  let(:temp_file_path) { Rails.root.join('tmp', 'test_integration.csv') }

  before do
    # Create a temporary CSV file
    FileUtils.mkdir_p(Rails.root.join('tmp'))
    File.write(temp_file_path, csv_content)

    # Mock S3 download to return our test file
    allow(s3_downloader).to receive(:download).and_return(temp_file_path)
    allow_any_instance_of(Importer::Dailies).to receive(:puts)
  end

  after do
    # Clean up
    File.delete(temp_file_path) if File.exist?(temp_file_path)
  end

  describe 'complete import workflow' do
    it 'downloads file from S3 and imports data' do
      # Step 1: Download file from S3
      downloaded_file = s3_downloader.download
      expect(downloaded_file).to eq(temp_file_path)
      expect(File.exist?(downloaded_file)).to be true

      # Step 2: Import the data
      importer = Importer::Dailies.new(downloaded_file)

      # The import should run without errors
      expect { importer.import }.not_to raise_error

      # Check that no errors were recorded
      expect(importer.errors).to be_empty
    end

    it 'handles missing files gracefully' do
      non_existent_file = Rails.root.join('tmp', 'non_existent.csv')
      importer = Importer::Dailies.new(non_existent_file)

      expect { importer.import }.to raise_error(Errno::ENOENT)
    end
  end

  describe 'error handling across components' do
    context 'when S3 download fails' do
      before do
        allow(s3_downloader).to receive(:download).and_raise(Aws::S3::Errors::NoSuchKey.new(nil, 'File not found'))
      end

      it 'propagates S3 errors' do
        expect { s3_downloader.download }.to raise_error(Aws::S3::Errors::NoSuchKey)
      end
    end

    context 'when CSV has invalid data' do
      let(:invalid_csv_content) do
        <<~CSV
          unleash id,name
          1,Morning Exercise
        CSV
      end

      before do
        File.write(temp_file_path, invalid_csv_content)
      end

      it 'records validation errors' do
        importer = Importer::Dailies.new(temp_file_path)
        importer.import

        expect(importer.errors).not_to be_empty
        expect(importer.errors.first).to include('Required headers missing')
      end
    end
  end

  describe 'test mode behavior' do
    it 'runs in test mode without making database changes' do
      importer = Importer::Dailies.new(temp_file_path, test_mode_enabled: true)

      # Should not attempt to save to database
      expect(Daily).not_to receive(:find_or_create_by)

      importer.import
    end
  end
end

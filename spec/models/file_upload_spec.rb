require 'rails_helper'

RSpec.describe FileUpload, type: :model do
  describe 'validations' do
    it 'validates presence of required fields' do
      file_upload = FileUpload.new
      expect(file_upload).not_to be_valid
      expect(file_upload.errors[:filename]).to include("can't be blank")
      expect(file_upload.errors[:file_type]).to include("can't be blank")
      expect(file_upload.errors[:import_type]).to include("can't be blank")
      expect(file_upload.errors[:status]).to include("can't be blank")
    end

    it 'validates file_type inclusion' do
      file_upload = FileUpload.new(file_type: 'invalid')
      expect(file_upload).not_to be_valid
      expect(file_upload.errors[:file_type]).to include("is not included in the list")
    end

    it 'validates import_type inclusion' do
      file_upload = FileUpload.new(import_type: 'invalid')
      expect(file_upload).not_to be_valid
      expect(file_upload.errors[:import_type]).to include("is not included in the list")
    end

    it 'validates status inclusion' do
      file_upload = FileUpload.new(status: 'invalid')
      expect(file_upload).not_to be_valid
      expect(file_upload.errors[:status]).to include("is not included in the list")
    end
  end

  describe 'file type detection' do
    let(:file_upload) { FileUpload.new(filename: 'test.xlsx') }

    it 'detects Excel files' do
      expect(file_upload.excel_file?).to be true
      expect(file_upload.csv_file?).to be false
      expect(file_upload.supported_file?).to be true
    end

    it 'detects CSV files' do
      file_upload.filename = 'test.csv'
      expect(file_upload.csv_file?).to be true
      expect(file_upload.excel_file?).to be false
      expect(file_upload.supported_file?).to be true
    end
  end

  describe 'status management' do
    let(:file_upload) do
      FileUpload.create!(
        filename: 'test.csv',
        file_type: 'dailies',
        import_type: 'import',
        status: 'pending',
        user_email: 'test@example.com'
      )
    end

    it 'can mark as processing' do
      file_upload.mark_as_processing!('job123')
      expect(file_upload.status).to eq('processing')
      expect(file_upload.job_id).to eq('job123')
    end

    it 'can mark as completed' do
      file_upload.mark_as_completed!
      expect(file_upload.status).to eq('completed')
      expect(file_upload.processed_at).to be_present
    end

    it 'can mark as failed' do
      file_upload.mark_as_failed!('Error message')
      expect(file_upload.status).to eq('failed')
      expect(file_upload.error_message).to eq('Error message')
      expect(file_upload.processed_at).to be_present
    end
  end
end

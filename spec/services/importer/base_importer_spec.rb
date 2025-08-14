require 'rails_helper'

RSpec.describe Importer::BaseImporter, type: :service do
  let(:filepath) { Rails.root.join('spec', 'fixtures', 'test.csv') }
  let(:importer) { described_class.new(filepath) }
  let(:csv_content) do
    <<~CSV
      name,description,age
      John Doe,Software Engineer,30
      Jane Smith,Designer,25
    CSV
  end

  before do
    # Create test CSV file
    FileUtils.mkdir_p(File.dirname(filepath))
    File.write(filepath, csv_content)
  end

  after do
    # Clean up test file
    File.delete(filepath) if File.exist?(filepath)
  end

  describe '#initialize' do
    it 'sets the filepath' do
      expect(importer.filepath).to eq(filepath)
    end

    it 'initializes errors as empty array' do
      expect(importer.errors).to eq([])
    end

    it 'sets test_mode_enabled to false by default' do
      expect(importer.test_mode_enabled).to be false
    end

    context 'with test mode enabled' do
      let(:importer) { described_class.new(filepath, test_mode_enabled: true) }

      it 'sets test_mode_enabled to true' do
        expect(importer.test_mode_enabled).to be true
      end
    end
  end

  describe '#import' do
    it 'raises NotImplementedError' do
      expect { importer.import }.to raise_error(NotImplementedError, 'Subclasses must implement the import method')
    end
  end

  describe '#missing_csv_headers' do
    let(:required_headers) { [ 'name', 'description', 'email' ] }

    context 'when all headers are present' do
      let(:csv_content) do
        <<~CSV
          name,description,email,age
          John Doe,Software Engineer,john@example.com,30
        CSV
      end

      it 'returns empty array' do
        expect(importer.send(:missing_csv_headers, [ 'name', 'description' ])).to eq([])
      end
    end

    context 'when some headers are missing' do
      it 'returns array of missing headers' do
        missing = importer.send(:missing_csv_headers, required_headers)
        expect(missing).to eq([ 'email' ])
      end
    end

    context 'when CSV file does not exist' do
      let(:nonexistent_filepath) { Rails.root.join('spec', 'fixtures', 'definitely_nonexistent.csv') }
      let(:nonexistent_importer) { described_class.new(nonexistent_filepath) }

      before do
        # Ensure the file definitely doesn't exist
        File.delete(nonexistent_filepath) if File.exist?(nonexistent_filepath)
      end

      it 'returns all required headers as missing' do
        missing = nonexistent_importer.send(:missing_csv_headers, required_headers)
        expect(missing).to eq(required_headers) # All headers are "missing" since file doesn't exist
      end
    end
  end

  describe '#csv_headers' do
    it 'returns headers from CSV file' do
      headers = importer.send(:csv_headers)
      expect(headers).to eq([ 'name', 'description', 'age' ])
    end

    context 'with empty CSV file' do
      let(:csv_content) { '' }

      it 'returns empty array' do
        headers = importer.send(:csv_headers)
        expect(headers).to eq([])
      end
    end
  end

  describe 'error handling' do
    it 'allows adding errors' do
      importer.errors << 'Test error'
      expect(importer.errors).to include('Test error')
    end
  end
end

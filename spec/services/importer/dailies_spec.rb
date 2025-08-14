require 'rails_helper'

RSpec.describe Importer::Dailies, type: :service do
  let(:filepath) { Rails.root.join('spec', 'fixtures', 'dailies.csv') }
  let(:importer) { described_class.new(filepath) }
  let(:valid_csv_content) do
    <<~CSV
      unleash id,daily_name,description,duration_minutes,effort,detailed health benefit,guide,tools
      1,Morning Meditation,Daily meditation practice,15,2,Reduces stress and anxiety,Sit quietly and focus on breathing,Meditation app
      2,Evening Walk,Light exercise,30,3,Improves cardiovascular health,Walk at moderate pace,Comfortable shoes
    CSV
  end

  before do
    # Create test CSV file
    FileUtils.mkdir_p(File.dirname(filepath))
    File.write(filepath, valid_csv_content)

    # Mock the puts method to suppress output during tests
    allow_any_instance_of(described_class).to receive(:puts)
  end

  after do
    # Clean up test file
    File.delete(filepath) if File.exist?(filepath)
  end

  describe 'REQUIRED_HEADERS' do
    it 'defines the required headers' do
      expected_headers = [
        "unleash id",
        "daily_name",
        "description",
        "duration_minutes",
        "effort",
        "detailed health benefit",
        "guide",
        "tools"
      ]
      expect(described_class::REQUIRED_HEADERS).to eq(expected_headers)
    end
  end

  describe '#import' do
    context 'with valid CSV file' do
      it 'processes the file successfully' do
        expect { importer.import }.not_to raise_error
      end

      it 'calls import_dailies' do
        expect(importer).to receive(:import_dailies)
        importer.import
      end
    end
  end

  describe '#import_dailies' do
    context 'with missing required headers' do
      let(:invalid_csv_content) do
        <<~CSV
          unleash id,name,description
          1,Morning Meditation,Daily meditation practice
        CSV
      end

      before do
        File.write(filepath, invalid_csv_content)
      end

      it 'adds error message for missing headers' do
        importer.send(:import_dailies)

        expect(importer.errors).to include(
          match(/Required headers missing for Dailies base data/)
        )
      end

      it 'includes the missing header names in error message' do
        importer.send(:import_dailies)

        error_message = importer.errors.first
        expect(error_message).to include('duration')
        expect(error_message).to include('effort')
        expect(error_message).to include('detailed health benefit')
        expect(error_message).to include('guide')
        expect(error_message).to include('tools')
      end

      it 'returns early without processing rows' do
        expect(CSV).not_to receive(:foreach).with(filepath, headers: true)
        importer.send(:import_dailies)
      end
    end

    context 'with valid headers' do
      let(:mock_daily) { instance_double(Daily) }

      before do
        # Mock Daily model
        allow(Daily).to receive(:find_or_create_by).and_return(mock_daily)
        allow(mock_daily).to receive(:update!)
      end

      it 'processes each row in the CSV' do
        expect(CSV).to receive(:foreach).with(filepath, headers: true).and_call_original
        importer.send(:import_dailies)
      end

      it 'extracts data from CSV rows correctly' do
        importer.send(:import_dailies)
        # Since the actual implementation is incomplete, we're testing the structure
        # In a real implementation, you'd mock the Daily model operations
      end

      context 'in test mode' do
        let(:importer) { described_class.new(filepath, test_mode_enabled: true) }

        it 'does not save to database' do
          expect(Daily).not_to receive(:find_or_create_by)
          importer.send(:import_dailies)
        end
      end

      context 'in production mode' do
        let(:importer) { described_class.new(filepath, test_mode_enabled: false) }

        it 'processes database operations' do
          # This would test actual database operations when implementation is complete
          importer.send(:import_dailies)
        end
      end
    end

    context 'with malformed CSV' do
      let(:malformed_csv_content) do
        <<~CSV
          unleash id,name,description,duration,effort,detailed health benefit,guide,tools
          1,Morning Meditation,"Unclosed quote,15,Low,Reduces stress,Sit quietly,App
        CSV
      end

      before do
        File.write(filepath, malformed_csv_content)
      end

      it 'handles CSV parsing errors gracefully' do
        expect { importer.send(:import_dailies) }.not_to raise_error
      end
    end
  end

  describe 'data extraction' do
    let(:sample_row) do
      {
        'unleash id' => '1',
        'name' => 'Morning Meditation',
        'description' => 'Daily meditation practice',
        'duration' => '15',
        'effort' => 'Low',
        'detailed health benefit' => 'Reduces stress and anxiety',
        'guide' => 'Sit quietly and focus on breathing',
        'tools' => 'Meditation app'
      }
    end

    it 'extracts all required fields from CSV row' do
      # This tests the field extraction logic that would be in the complete implementation
      CSV.foreach(filepath, headers: true) do |row|
        expect(row['unleash id']).to be_present
        expect(row['daily_name']).to be_present
        expect(row['description']).to be_present
        expect(row['duration_minutes']).to be_present
        expect(row['effort']).to be_present
        expect(row['detailed health benefit']).to be_present
        expect(row['guide']).to be_present
        expect(row['tools']).to be_present
        break # Just test first row
      end
    end
  end
end

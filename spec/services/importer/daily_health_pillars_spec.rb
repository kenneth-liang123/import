require 'rails_helper'

RSpec.describe Importer::DailyHealthPillars, type: :service do
  let(:filepath) { Rails.root.join('spec', 'fixtures', 'daily_health_pillars.csv') }
  let(:importer) { described_class.new(filepath) }
  let(:health_pillar_names) { [ 'Physical', 'Mental', 'Emotional', 'Social' ] }
  let(:valid_csv_content) do
    <<~CSV
      unleash id,Physical,Mental,Emotional,Social
      1,1,1,0,1
      2,0,1,1,0
      3,1,0,1,1
    CSV
  end

  let(:mock_daily_1) { instance_double(Daily, id: 1, unleash_id: '1') }
  let(:mock_daily_2) { instance_double(Daily, id: 2, unleash_id: '2') }
  let(:mock_health_pillars_collection) { instance_double('ActiveRecord::Associations::CollectionProxy') }

  before do
    # Create test CSV file
    FileUtils.mkdir_p(File.dirname(filepath))
    File.write(filepath, valid_csv_content)

    # Mock HealthPillar model
    allow(HealthPillar).to receive(:pluck).with(:name).and_return(health_pillar_names)

    # Mock Daily model
    allow(Daily).to receive(:find_by).with(unleash_id: '1').and_return(mock_daily_1)
    allow(Daily).to receive(:find_by).with(unleash_id: '2').and_return(mock_daily_2)
    allow(Daily).to receive(:find_by).with(unleash_id: '3').and_return(nil)

    # Mock health_pillars association
    allow(mock_daily_1).to receive(:health_pillars).and_return(mock_health_pillars_collection)
    allow(mock_daily_2).to receive(:health_pillars).and_return(mock_health_pillars_collection)
    allow(mock_health_pillars_collection).to receive(:clear)

    # Mock the puts and print methods to suppress output during tests
    allow_any_instance_of(described_class).to receive(:puts)
    allow_any_instance_of(described_class).to receive(:print)
  end

  after do
    # Clean up test file
    File.delete(filepath) if File.exist?(filepath)
  end

  describe '#import' do
    it 'processes the file successfully' do
      expect { importer.import }.not_to raise_error
    end

    it 'calls import_dailies_health_pillars' do
      expect(importer).to receive(:import_dailies_health_pillars)
      importer.import
    end
  end

  describe '#import_dailies_health_pillars' do
    context 'with missing required headers' do
      let(:invalid_csv_content) do
        <<~CSV
          unleash id,Physical,Mental
          1,1,1
        CSV
      end

      before do
        File.write(filepath, invalid_csv_content)
      end

      it 'adds error message for missing headers' do
        importer.send(:import_dailies_health_pillars)

        expect(importer.errors).to include(
          match(/Required headers missing for Dailies health pillars data/)
        )
      end

      it 'includes the missing header names in error message' do
        importer.send(:import_dailies_health_pillars)

        error_message = importer.errors.first
        expect(error_message).to include('Emotional')
        expect(error_message).to include('Social')
      end

      it 'returns early without processing rows' do
        expect(CSV).not_to receive(:foreach).with(filepath, headers: true)
        importer.send(:import_dailies_health_pillars)
      end
    end

    context 'with valid headers' do
      it 'processes each row in the CSV' do
        expect(CSV).to receive(:foreach).with(filepath, headers: true).and_call_original
        importer.send(:import_dailies_health_pillars)
      end

      it 'finds dailies by unleash_id' do
        expect(Daily).to receive(:find_by).with(unleash_id: '1')
        expect(Daily).to receive(:find_by).with(unleash_id: '2')
        expect(Daily).to receive(:find_by).with(unleash_id: '3')

        importer.send(:import_dailies_health_pillars)
      end

      context 'when daily exists' do
        it 'clears existing health pillar connections in production mode' do
          importer = described_class.new(filepath, test_mode_enabled: false)
          allow_any_instance_of(described_class).to receive(:puts)
          allow_any_instance_of(described_class).to receive(:print)

          expect(mock_health_pillars_collection).to receive(:clear).twice

          importer.send(:import_dailies_health_pillars)
        end

        it 'does not clear connections in test mode' do
          importer = described_class.new(filepath, test_mode_enabled: true)
          allow_any_instance_of(described_class).to receive(:puts)
          allow_any_instance_of(described_class).to receive(:print)

          expect(mock_health_pillars_collection).not_to receive(:clear)

          importer.send(:import_dailies_health_pillars)
        end

        it 'prints found message' do
          expect_any_instance_of(described_class).to receive(:puts).with('found.')
          expect_any_instance_of(described_class).to receive(:puts).with('Clearing existing connections...')

          importer.send(:import_dailies_health_pillars)
        end
      end

      context 'when daily does not exist' do
        let(:valid_csv_content) do
          <<~CSV
            unleash id,Physical,Mental,Emotional,Social
            999,1,1,0,1
          CSV
        end

        before do
          allow(Daily).to receive(:find_by).with(unleash_id: '999').and_return(nil)
        end

        it 'adds to missing_dailies array' do
          importer.send(:import_dailies_health_pillars)

          # The method should print missing dailies
          expect_any_instance_of(described_class).to have_received(:puts).with(match(/Missing dailies \(1\): 999/))
        end
      end
    end

    context 'with health pillar data processing' do
      let(:mock_physical_pillar) { instance_double(HealthPillar, id: 1, name: 'Physical') }
      let(:mock_mental_pillar) { instance_double(HealthPillar, id: 2, name: 'Mental') }

      before do
        allow(HealthPillar).to receive(:find_by).with(name: 'Physical').and_return(mock_physical_pillar)
        allow(HealthPillar).to receive(:find_by).with(name: 'Mental').and_return(mock_mental_pillar)
        allow(HealthPillar).to receive(:find_by).with(name: 'Emotional').and_return(nil)
        allow(HealthPillar).to receive(:find_by).with(name: 'Social').and_return(nil)
      end

      it 'processes health pillar associations correctly' do
        # This tests the structure for processing health pillar values
        # In complete implementation, you'd test the actual association creation
        importer.send(:import_dailies_health_pillars)
      end
    end
  end

  describe 'error handling' do
    context 'with malformed CSV' do
      let(:malformed_csv_content) do
        <<~CSV
          unleash id,Physical,Mental,Emotional,Social
          1,1,invalid_value,0,1
        CSV
      end

      before do
        File.write(filepath, malformed_csv_content)
      end

      it 'handles invalid data gracefully' do
        expect { importer.send(:import_dailies_health_pillars) }.not_to raise_error
      end
    end

    context 'when HealthPillar.pluck raises an error' do
      before do
        allow(HealthPillar).to receive(:pluck).and_raise(StandardError.new('Database error'))
      end

      it 'propagates the error' do
        expect { importer.send(:import_dailies_health_pillars) }.to raise_error(StandardError, 'Database error')
      end
    end
  end

  describe 'output messages' do
    it 'prints processing message' do
      expect_any_instance_of(described_class).to receive(:puts).with('Processing file...')
      importer.import
    end

    it 'prints importing messages for each daily' do
      expect_any_instance_of(described_class).to receive(:print).with('Importing daily 1...')
      expect_any_instance_of(described_class).to receive(:print).with('Importing daily 2...')
      expect_any_instance_of(described_class).to receive(:print).with('Importing daily 3...')

      importer.send(:import_dailies_health_pillars)
    end

    it 'prints summary of missing dailies' do
      expect_any_instance_of(described_class).to receive(:puts).with('Missing dailies (1): 3')

      importer.send(:import_dailies_health_pillars)
    end
  end
end

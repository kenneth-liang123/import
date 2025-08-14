# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe ImportDailyHealthPillarsJob, type: :job do

  let(:csv_content) do
    <<~CSV
      daily_name,health_pillar_Mental Wellness,health_pillar_Physical Activity,health_pillar_Nutrition
      Morning Meditation,true,false,false
      Evening Walk,false,true,false
      Gratitude Journal,true,false,true
    CSV
  end

  let(:test_file_path) { '/tmp/test_health_pillars_job.csv' }

  before do
    # Setup test environment
    Sidekiq::Testing.fake!
    
    # Create test CSV file
    File.write(test_file_path, csv_content)
    
    # Create required Daily records
    @meditation_daily = Daily.create!(
      unleash_id: '1',
      name: 'Morning Meditation',
      description: 'Test meditation',
      duration_minutes: 10,
      effort: 2
    )
    
    @walk_daily = Daily.create!(
      unleash_id: '2',
      name: 'Evening Walk',
      description: 'Test walk',
      duration_minutes: 30,
      effort: 3
    )
    
    @journal_daily = Daily.create!(
      unleash_id: '3',
      name: 'Gratitude Journal',
      description: 'Test journal',
      duration_minutes: 5,
      effort: 1
    )
    
    # Create HealthPillar records
    @mental_wellness = HealthPillar.create!(name: 'Mental Wellness')
    @physical_activity = HealthPillar.create!(name: 'Physical Activity')
    @nutrition = HealthPillar.create!(name: 'Nutrition')
    
    # Clear any existing jobs
    Sidekiq::Worker.clear_all
  end

  after do
    # Cleanup test file
    File.delete(test_file_path) if File.exist?(test_file_path)
    
    # Reset Sidekiq testing mode
    Sidekiq::Testing.disable!
  end

  describe '#perform' do
    context 'with valid CSV file' do
      it 'processes the file successfully' do
        result = described_class.new.perform(test_file_path)
        
        expect(result[:status]).to eq('completed')
        expect(result[:processed_rows]).to eq(3)
        expect(result[:errors]).to be_empty
        expect(result[:relationships_created]).to eq(4) # 1+1+2 relationships
        expect(result[:file_path]).to eq(test_file_path)
        expect(result[:duration]).to be > 0
      end

      it 'creates health pillar relationships correctly' do
        described_class.new.perform(test_file_path)
        
        # Check Morning Meditation relationships
        meditation_pillars = @meditation_daily.reload.health_pillars.pluck(:name)
        expect(meditation_pillars).to include('Mental Wellness')
        expect(meditation_pillars).not_to include('Physical Activity', 'Nutrition')
        
        # Check Evening Walk relationships
        walk_pillars = @walk_daily.reload.health_pillars.pluck(:name)
        expect(walk_pillars).to include('Physical Activity')
        expect(walk_pillars).not_to include('Mental Wellness', 'Nutrition')
        
        # Check Gratitude Journal relationships
        journal_pillars = @journal_daily.reload.health_pillars.pluck(:name)
        expect(journal_pillars).to include('Mental Wellness', 'Nutrition')
        expect(journal_pillars).not_to include('Physical Activity')
      end

      it 'clears existing relationships before creating new ones' do
        # Create existing relationship
        @meditation_daily.health_pillars << @nutrition
        expect(@meditation_daily.health_pillars.count).to eq(1)
        
        described_class.new.perform(test_file_path)
        
        # Should have new relationship, not old one
        meditation_pillars = @meditation_daily.reload.health_pillars.pluck(:name)
        expect(meditation_pillars).to eq(['Mental Wellness'])
        expect(meditation_pillars).not_to include('Nutrition')
      end

      it 'handles idempotent operations' do
        # Run twice
        described_class.new.perform(test_file_path)
        described_class.new.perform(test_file_path)
        
        # Should have same relationships, not duplicates
        meditation_pillars = @meditation_daily.reload.health_pillars.pluck(:name)
        expect(meditation_pillars).to eq(['Mental Wellness'])
      end
    end

    context 'with missing dailies' do
      let(:csv_with_missing_daily) do
        <<~CSV
          daily_name,health_pillar_Mental Wellness,health_pillar_Physical Activity
          Morning Meditation,true,false
          Nonexistent Daily,true,false
          Evening Walk,false,true
        CSV
      end

      it 'tracks missing dailies and continues processing' do
        File.write(test_file_path, csv_with_missing_daily)
        
        result = described_class.new.perform(test_file_path)
        
        expect(result[:status]).to eq('completed')
        expect(result[:processed_rows]).to eq(2) # Only found dailies
        expect(result[:missing_dailies]).to include('Nonexistent Daily')
        
        # Should still process valid dailies
        meditation_pillars = @meditation_daily.reload.health_pillars.pluck(:name)
        expect(meditation_pillars).to include('Mental Wellness')
        
        walk_pillars = @walk_daily.reload.health_pillars.pluck(:name)
        expect(walk_pillars).to include('Physical Activity')
      end
    end

    context 'with test mode enabled' do
      it 'runs without making database changes' do
        initial_relationships = DailyHealthPillar.count
        
        described_class.new.perform(test_file_path, { 'test_mode' => true })
        
        expect(DailyHealthPillar.count).to eq(initial_relationships)
      end
    end

    context 'with invalid file path' do
      it 'raises appropriate error for missing file' do
        expect {
          described_class.new.perform('/nonexistent/file.csv')
        }.to raise_error(ArgumentError, /File not found/)
      end
    end

    context 'with missing required headers' do
      let(:invalid_headers_csv) do
        <<~CSV
          wrong_header,another_wrong_header
          value1,value2
        CSV
      end

      it 'raises error for missing daily_name header' do
        File.write(test_file_path, invalid_headers_csv)
        
        expect {
          described_class.new.perform(test_file_path)
        }.to raise_error(ArgumentError, /Missing required CSV header: daily_name/)
      end
    end

    context 'with no health pillar columns' do
      let(:no_pillars_csv) do
        <<~CSV
          daily_name,other_column
          Morning Meditation,some_value
        CSV
      end

      it 'raises error when no health pillar columns found' do
        File.write(test_file_path, no_pillars_csv)
        
        expect {
          described_class.new.perform(test_file_path)
        }.to raise_error(ArgumentError, /No health pillar columns found/)
      end
    end

    context 'with S3 file path' do
      let(:s3_file_path) { 's3://test-bucket/test-pillars.csv' }
      let(:mock_downloader) { instance_double(S3FileDownloader) }

      before do
        File.write(test_file_path, csv_content)
        allow(S3FileDownloader).to receive(:new).with('test-pillars.csv', 'test-bucket').and_return(mock_downloader)
        allow(mock_downloader).to receive(:download).and_return(test_file_path)
      end

      it 'downloads file from S3 and processes it' do
        result = described_class.new.perform(s3_file_path)
        
        expect(result[:status]).to eq('completed')
        expect(result[:file_path]).to eq(s3_file_path)
        expect(S3FileDownloader).to have_received(:new).with('test-pillars.csv', 'test-bucket')
        expect(mock_downloader).to have_received(:download)
      end
    end

    context 'with dynamic health pillar discovery' do
      let(:dynamic_pillars_csv) do
        <<~CSV
          daily_name,health_pillar_Sleep Quality,health_pillar_Social Connection,health_pillar_Mental Wellness
          Morning Meditation,false,false,true
          Evening Walk,true,true,false
        CSV
      end

      before do
        # Create additional health pillars
        HealthPillar.create!(name: 'Sleep Quality')
        HealthPillar.create!(name: 'Social Connection')
      end

      it 'discovers and processes dynamic health pillar columns' do
        File.write(test_file_path, dynamic_pillars_csv)
        
        result = described_class.new.perform(test_file_path)
        
        expect(result[:status]).to eq('completed')
        expect(result[:processed_rows]).to eq(2)
        
        # Check relationships were created for new pillars
        walk_pillars = @walk_daily.reload.health_pillars.pluck(:name)
        expect(walk_pillars).to include('Sleep Quality', 'Social Connection')
        expect(walk_pillars).not_to include('Mental Wellness')
        
        meditation_pillars = @meditation_daily.reload.health_pillars.pluck(:name)
        expect(meditation_pillars).to include('Mental Wellness')
        expect(meditation_pillars).not_to include('Sleep Quality', 'Social Connection')
      end
    end

    context 'with batch processing' do
      let(:large_csv) do
        csv = "daily_name,health_pillar_Mental Wellness,health_pillar_Physical Activity\n"
        
        # Create enough rows to test batch processing (50+ rows)
        60.times do |i|
          daily_name = "Test Daily #{i}"
          Daily.create!(
            unleash_id: "test_#{i}",
            name: daily_name,
            description: "Test daily #{i}",
            duration_minutes: 10,
            effort: 2
          )
          csv += "#{daily_name},true,false\n"
        end
        
        csv
      end

      it 'processes large files in batches' do
        File.write(test_file_path, large_csv)
        
        result = described_class.new.perform(test_file_path)
        
        expect(result[:status]).to eq('completed')
        expect(result[:processed_rows]).to eq(60)
        expect(result[:relationships_created]).to eq(60) # One relationship per daily
      end
    end
  end

  describe 'job enqueueing' do
    it 'enqueues the job successfully' do
      expect {
        ImportDailyHealthPillarsJob.perform_async(test_file_path)
      }.to change(ImportDailyHealthPillarsJob.jobs, :size).by(1)
    end

    it 'enqueues with correct arguments' do
      ImportDailyHealthPillarsJob.perform_async(test_file_path, { clear_existing: false })
      
      job = ImportDailyHealthPillarsJob.jobs.last
      expect(job['args']).to eq([test_file_path, { 'clear_existing' => false }])
    end

    it 'processes enqueued jobs when performed' do
      Sidekiq::Testing.inline! do
        expect {
          ImportDailyHealthPillarsJob.perform_async(test_file_path)
        }.to change { DailyHealthPillar.count }.by(4)
      end
    end
  end

  describe 'error handling and resilience' do
    before do
      Sidekiq::Testing.inline!
    end

    it 'handles database errors gracefully' do
      # Ensure there's a daily that will be processed
      File.write(test_file_path, csv_content)
      
      # Mock a database error on the daily_health_pillars association
      allow_any_instance_of(Daily).to receive(:daily_health_pillars).and_raise(ActiveRecord::StatementInvalid, 'Database error')
      
      # Job should complete but log the error instead of crashing
      result = nil
      expect {
        result = ImportDailyHealthPillarsJob.perform_async(test_file_path)
      }.not_to raise_error
      
      # The job should complete with errors logged
      # Note: In inline testing, perform_async runs immediately and returns the result
    end

    it 'logs errors appropriately' do
      allow(Rails.logger).to receive(:error)
      allow_any_instance_of(ImportDailyHealthPillarsJob).to receive(:perform_import).and_raise(StandardError, 'Test error')
      
      expect {
        ImportDailyHealthPillarsJob.perform_async(test_file_path)
      }.to raise_error(StandardError)
      
      expect(Rails.logger).to have_received(:error).at_least(:once)
    end
  end

  describe 'progress tracking' do
    it 'reports progress during processing' do
      allow(Rails.logger).to receive(:info)
      
      described_class.new.perform(test_file_path)
      
      expect(Rails.logger).to have_received(:info).with(/Starting ImportDailyHealthPillarsJob/)
      expect(Rails.logger).to have_received(:info).with(/ImportDailyHealthPillarsJob completed successfully/)
    end
  end
end

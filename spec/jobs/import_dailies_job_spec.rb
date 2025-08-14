# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe ImportDailiesJob, type: :job do
  let(:csv_content) do
    <<~CSV
      unleash id,daily_name,description,duration_minutes,effort,category,step_by_step_guide,scientific_explanation,detailed health benefit,guide,tools
      1,Morning Meditation,10 minutes of mindful breathing,10,2,Mental Wellness,1. Find quiet space,Meditation reduces cortisol,Reduces stress,Use guided apps,Meditation app
      2,Evening Walk,30-minute neighborhood walk,30,3,Physical Activity,1. Put on shoes,Walking increases cardio health,Improves cardiovascular health,Plan safe routes,Walking shoes
    CSV
  end

  let(:test_file_path) { '/tmp/test_dailies_job.csv' }

  before do
    # Setup test environment
    Sidekiq::Testing.fake!
    
    # Create test CSV file
    File.write(test_file_path, csv_content)
    
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
        expect(result[:processed_rows]).to eq(2)
        expect(result[:errors]).to be_empty
        expect(result[:file_path]).to eq(test_file_path)
        expect(result[:duration]).to be > 0
      end

      it 'creates Daily records in the database' do
        expect {
          described_class.new.perform(test_file_path)
        }.to change { Daily.count }.by(2)
        
        daily1 = Daily.find_by(name: 'Morning Meditation')
        expect(daily1).to be_present
        expect(daily1.unleash_id).to eq('1')
        expect(daily1.description).to eq('10 minutes of mindful breathing')
        
        daily2 = Daily.find_by(name: 'Evening Walk')
        expect(daily2).to be_present
        expect(daily2.unleash_id).to eq('2')
      end

      it 'handles duplicate records idempotently' do
        # Create initial record
        Daily.create!(
          unleash_id: '1',
          name: 'Morning Meditation',
          description: 'Existing description',
          duration_minutes: 10,
          effort: 2
        )
        
        expect {
          described_class.new.perform(test_file_path)
        }.to change { Daily.count }.by(1) # Only one new record
        
        # Check that existing record wasn't duplicated
        dailies = Daily.where(name: 'Morning Meditation')
        expect(dailies.count).to eq(1)
      end
    end

    context 'with test mode enabled' do
      it 'runs without making database changes' do
        expect {
          described_class.new.perform(test_file_path, { 'test_mode' => true })
        }.not_to change { Daily.count }
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

      it 'raises error for missing headers' do
        File.write(test_file_path, invalid_headers_csv)
        
        expect {
          described_class.new.perform(test_file_path)
        }.to raise_error(ArgumentError, /Missing required CSV headers/)
      end
    end
  end

  describe 'job enqueueing' do
    it 'enqueues the job successfully' do
      expect {
        ImportDailiesJob.perform_async(test_file_path)
      }.to change(ImportDailiesJob.jobs, :size).by(1)
    end

    it 'enqueues with correct arguments' do
      ImportDailiesJob.perform_async(test_file_path, { 'test_mode' => true })
      
      job = ImportDailiesJob.jobs.last
      expect(job['args']).to eq([test_file_path, { 'test_mode' => true }])
    end

    it 'processes enqueued jobs when performed' do
      Sidekiq::Testing.inline! do
        expect {
          ImportDailiesJob.perform_async(test_file_path)
        }.to change { Daily.count }.by(2)
      end
    end
  end

  describe 'progress tracking' do
    it 'reports progress during processing' do
      allow(Rails.logger).to receive(:info)
      
      described_class.new.perform(test_file_path)
      
      expect(Rails.logger).to have_received(:info).with(/Starting ImportDailiesJob/)
      expect(Rails.logger).to have_received(:info).with(/ImportDailiesJob completed successfully/)
    end
  end
end

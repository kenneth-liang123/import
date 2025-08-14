# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
require 'sidekiq/api'

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe ImportOrchestrator, type: :service do

  before do
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all
  end

  after do
    Sidekiq::Testing.disable!
  end

  describe '.import_dailies' do
    let(:file_path) { '/tmp/test_dailies.csv' }
    let(:options) { { test_mode: true } }

    it 'enqueues ImportDailiesJob with correct parameters' do
      result = described_class.import_dailies(file_path, options)
      
      expect(result[:job_class]).to eq('ImportDailiesJob')
      expect(result[:file_path]).to eq(file_path)
      expect(result[:status]).to eq('enqueued')
      expect(result[:options]).to eq(options)
      expect(result[:job_id]).to be_present
      
      # Check job was actually enqueued
      expect(ImportDailiesJob.jobs.size).to eq(1)
      job = ImportDailiesJob.jobs.last
      # Sidekiq converts symbol keys to strings
      expect(job['args']).to eq([file_path, options.stringify_keys])
    end

    it 'logs the job enqueueing' do
      expect(Rails.logger).to receive(:info).with(/Enqueued ImportDailiesJob with ID/)
      
      described_class.import_dailies(file_path, options)
    end
  end

  describe '.import_daily_health_pillars' do
    let(:file_path) { '/tmp/test_pillars.csv' }
    let(:options) { { clear_existing: false } }

    it 'enqueues ImportDailyHealthPillarsJob with correct parameters' do
      result = described_class.import_daily_health_pillars(file_path, options)
      
      expect(result[:job_class]).to eq('ImportDailyHealthPillarsJob')
      expect(result[:file_path]).to eq(file_path)
      expect(result[:status]).to eq('enqueued')
      expect(result[:options]).to eq(options)
      expect(result[:job_id]).to be_present
      
      # Check job was actually enqueued
      expect(ImportDailyHealthPillarsJob.jobs.size).to eq(1)
      job = ImportDailyHealthPillarsJob.jobs.last
      expect(job['args']).to eq([file_path, options.stringify_keys])
    end

    it 'logs the job enqueueing' do
      expect(Rails.logger).to receive(:info).with(/Enqueued ImportDailyHealthPillarsJob with ID/)
      
      described_class.import_daily_health_pillars(file_path, options)
    end
  end

  describe '.import_full_dataset' do
    let(:dailies_file) { '/tmp/dailies.csv' }
    let(:pillars_file) { '/tmp/pillars.csv' }
    let(:options) { { delay_seconds: 60 } }

    it 'enqueues both jobs in sequence' do
      result = described_class.import_full_dataset(dailies_file, pillars_file, options)
      
      expect(result[:dailies_job_id]).to be_present
      expect(result[:pillars_job_id]).to be_present
      expect(result[:status]).to eq('enqueued')
      expect(result[:sequence]).to eq('dailies_first_then_pillars')
      
      # Check both jobs were enqueued
      expect(ImportDailiesJob.jobs.size).to eq(1)
      expect(ImportDailyHealthPillarsJob.jobs.size).to eq(1)
      
      # Check dailies job is immediate
      dailies_job = ImportDailiesJob.jobs.last
      expect(dailies_job['args']).to eq([dailies_file, options.stringify_keys])
      
      # Check pillars job is delayed
      pillars_job = ImportDailyHealthPillarsJob.jobs.last
      expect(pillars_job['args']).to eq([pillars_file, options.stringify_keys])
      expect(pillars_job['at']).to be_present # Should have delay
    end

    it 'uses default delay when not specified' do
      result = described_class.import_full_dataset(dailies_file, pillars_file)
      
      expect(result[:status]).to eq('enqueued')
      
      # Check default delay is applied (30 seconds)
      pillars_job = ImportDailyHealthPillarsJob.jobs.last
      expect(pillars_job['at']).to be_within(5).of(Time.now.to_f + 30)
    end

    it 'logs the sequential job enqueueing' do
      expect(Rails.logger).to receive(:info).with(/Enqueued sequential import jobs/)
      
      described_class.import_full_dataset(dailies_file, pillars_file)
    end
  end

  describe '.batch_import_dailies' do
    let(:file_paths) { ['/tmp/file1.csv', '/tmp/file2.csv', '/tmp/file3.csv'] }
    let(:options) { { stagger_seconds: 10 } }

    it 'enqueues multiple jobs with staggered timing' do
      result = described_class.batch_import_dailies(file_paths, options)
      
      expect(result[:job_ids].size).to eq(3)
      expect(result[:job_class]).to eq('ImportDailiesJob')
      expect(result[:file_count]).to eq(3)
      expect(result[:status]).to eq('enqueued')
      
      # Check all jobs were enqueued
      expect(ImportDailiesJob.jobs.size).to eq(3)
      
      # Check staggered timing
      jobs = ImportDailiesJob.jobs
      expect(jobs[0]['at']).to be_nil # First job immediate
      expect(jobs[1]['at']).to be_within(5).of(Time.now.to_f + 10) # Second job +10s
      expect(jobs[2]['at']).to be_within(5).of(Time.now.to_f + 20) # Third job +20s
    end

    it 'uses default stagger timing when not specified' do
      described_class.batch_import_dailies(file_paths)
      
      jobs = ImportDailiesJob.jobs
      expect(jobs[1]['at']).to be_within(5).of(Time.now.to_f + 5) # Default 5s stagger
    end

    it 'logs the batch job enqueueing' do
      expect(Rails.logger).to receive(:info).with(/Enqueued 3 batch import jobs/)
      
      described_class.batch_import_dailies(file_paths)
    end
  end

  describe '.job_status' do
    let(:job_id) { 'test_job_id_123' }

    context 'when job is queued' do
      before do
        # Mock a queued job
        mock_job = double('Job', jid: job_id)
        mock_queue = double('Queue')
        allow(mock_queue).to receive(:find_job).with(job_id).and_return(mock_job)
        allow(Sidekiq::Queue).to receive(:new).and_return(mock_queue)
      end

      it 'returns queued status' do
        result = described_class.job_status(job_id)
        
        expect(result[:status]).to eq('queued')
        expect(result[:job_id]).to eq(job_id)
      end
    end

    context 'when job is processing' do
      before do
        # Mock no queued job
        mock_queue = double('Queue')
        allow(mock_queue).to receive(:find_job).with(job_id).and_return(nil)
        allow(Sidekiq::Queue).to receive(:new).and_return(mock_queue)
        
        # Mock a working job
        mock_workers = double('Workers')
        working_job = [nil, nil, { 'payload' => { 'jid' => job_id } }]
        allow(mock_workers).to receive(:find).and_return(working_job)
        allow(Sidekiq::Workers).to receive(:new).and_return(mock_workers)
      end

      it 'returns processing status' do
        result = described_class.job_status(job_id)
        
        expect(result[:status]).to eq('processing')
        expect(result[:job_id]).to eq(job_id)
      end
    end

    context 'when job is completed' do
      before do
        # Mock no job found anywhere
        mock_queue = double('Queue')
        allow(mock_queue).to receive(:find_job).with(job_id).and_return(nil)
        allow(Sidekiq::Queue).to receive(:new).and_return(mock_queue)
        
        mock_workers = double('Workers')
        allow(mock_workers).to receive(:find).and_return(nil)
        allow(Sidekiq::Workers).to receive(:new).and_return(mock_workers)
        
        mock_retry_set = double('RetrySet')
        allow(mock_retry_set).to receive(:find).and_return(nil)
        allow(Sidekiq::RetrySet).to receive(:new).and_return(mock_retry_set)
        
        mock_dead_set = double('DeadSet')
        allow(mock_dead_set).to receive(:find).and_return(nil)
        allow(Sidekiq::DeadSet).to receive(:new).and_return(mock_dead_set)
      end

      it 'returns completed status' do
        result = described_class.job_status(job_id)
        
        expect(result[:status]).to eq('completed')
        expect(result[:job_id]).to eq(job_id)
      end
    end
  end

  describe '.import_stats' do
    before do
      # Mock Sidekiq stats
      mock_stats = double('Stats')
      allow(mock_stats).to receive(:enqueued).and_return(10)
      allow(mock_stats).to receive(:processed).and_return(100)
      allow(mock_stats).to receive(:failed).and_return(5)
      allow(mock_stats).to receive(:workers_size).and_return(3)
      allow(Sidekiq::Stats).to receive(:new).and_return(mock_stats)
      
      # Mock queue with import jobs
      import_job1 = double('Job', klass: 'ImportDailiesJob')
      import_job2 = double('Job', klass: 'ImportDailyHealthPillarsJob')
      other_job = double('Job', klass: 'OtherJob')
      
      mock_queue = double('Queue')
      allow(mock_queue).to receive(:select).and_return([import_job1, import_job2])
      allow(mock_queue).to receive(:latency).and_return(2.5)
      allow(Sidekiq::Queue).to receive(:new).with('default').and_return(mock_queue)
    end

    it 'returns comprehensive import statistics' do
      result = described_class.import_stats
      
      expect(result[:total_enqueued]).to eq(10)
      expect(result[:total_processed]).to eq(100)
      expect(result[:total_failed]).to eq(5)
      expect(result[:import_jobs_queued]).to eq(2)
      expect(result[:workers_busy]).to eq(3)
      expect(result[:queue_latency]).to eq(2.5)
    end
  end

  describe '.clear_failed_import_jobs' do
    before do
      # Mock failed import jobs
      import_dead_job = double('DeadJob', klass: 'ImportDailiesJob')
      other_dead_job = double('DeadJob', klass: 'OtherJob')
      import_retry_job = double('RetryJob', klass: 'ImportDailyHealthPillarsJob')
      
      allow(import_dead_job).to receive(:delete)
      allow(import_retry_job).to receive(:delete)
      
      mock_dead_set = double('DeadSet')
      allow(mock_dead_set).to receive(:each).and_yield(import_dead_job).and_yield(other_dead_job)
      allow(Sidekiq::DeadSet).to receive(:new).and_return(mock_dead_set)
      
      mock_retry_set = double('RetrySet')
      allow(mock_retry_set).to receive(:each).and_yield(import_retry_job)
      allow(Sidekiq::RetrySet).to receive(:new).and_return(mock_retry_set)
    end

    it 'clears only import-related failed jobs' do
      result = described_class.clear_failed_import_jobs
      
      expect(result[:dead_jobs_cleared]).to eq(1)
      expect(result[:retry_jobs_cleared]).to eq(1)
      expect(result[:total_cleared]).to eq(2)
    end

    it 'logs the cleanup results' do
      expect(Rails.logger).to receive(:info).with(/Cleared 1 dead and 1 retry import jobs/)
      
      described_class.clear_failed_import_jobs
    end
  end

  describe '.validate_import_file' do
    context 'with local file' do
      let(:existing_file) { '/tmp/existing_file.csv' }
      let(:missing_file) { '/tmp/missing_file.csv' }

      before do
        File.write(existing_file, 'test content')
      end

      after do
        File.delete(existing_file) if File.exist?(existing_file)
      end

      it 'validates existing file successfully' do
        result = described_class.validate_import_file(existing_file, 'dailies')
        
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
        expect(result[:file_path]).to eq(existing_file)
        expect(result[:import_type]).to eq('dailies')
      end

      it 'reports missing file error' do
        result = described_class.validate_import_file(missing_file, 'dailies')
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(/File not found/)
      end
    end

    context 'with S3 file' do
      let(:s3_file) { 's3://bucket/file.csv' }

      it 'skips validation for S3 files' do
        result = described_class.validate_import_file(s3_file, 'dailies')
        
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
      end
    end

    context 'with invalid import type' do
      it 'reports invalid import type error' do
        result = described_class.validate_import_file('/tmp/file.csv', 'invalid_type')
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(/Invalid import type/)
      end
    end

    it 'accepts valid import types' do
      %w[dailies daily_health_pillars].each do |type|
        File.write('/tmp/test.csv', 'test')
        result = described_class.validate_import_file('/tmp/test.csv', type)
        expect(result[:valid]).to be true
        File.delete('/tmp/test.csv')
      end
    end
  end
end

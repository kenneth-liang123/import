#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../config/environment'

puts "🧪 Testing Sidekiq Job Setup"
puts "=" * 40

# Test 1: Check if Sidekiq is properly configured
puts "\n1. Testing Sidekiq Configuration..."
begin
  require 'sidekiq/api'
  stats = Sidekiq::Stats.new
  puts "   ✅ Sidekiq is configured"
  puts "   📊 Current stats: #{stats.processed} processed, #{stats.failed} failed"
rescue => e
  puts "   ❌ Sidekiq configuration error: #{e.message}"
  exit 1
end

# Test 2: Check if Redis is accessible
puts "\n2. Testing Redis Connection..."
begin
  Sidekiq.redis { |conn| conn.ping }
  puts "   ✅ Redis connection successful"
rescue => e
  puts "   ❌ Redis connection failed: #{e.message}"
  puts "   💡 Make sure Redis is running: brew services start redis"
  exit 1
end

# Test 3: Check if our job classes are loaded
puts "\n3. Testing Job Classes..."
begin
  ImportDailiesJob
  ImportDailyHealthPillarsJob
  ImportOrchestrator
  puts "   ✅ All job classes loaded successfully"
rescue => e
  puts "   ❌ Job class loading error: #{e.message}"
  exit 1
end

# Test 4: Create a sample CSV for testing
puts "\n4. Creating Sample Test Files..."
begin
  # Create dailies test file
  dailies_content = <<~CSV
    daily_name,description,category
    Morning Meditation,10 minutes of mindfulness,Mental Health
    Evening Walk,30 minute neighborhood walk,Physical Activity
    Gratitude Journal,Write 3 things you're grateful for,Mental Health
  CSV
  
  File.write('/tmp/test_dailies.csv', dailies_content)
  puts "   ✅ Sample dailies CSV created: /tmp/test_dailies.csv"
  
  # Create health pillars test file
  pillars_content = <<~CSV
    daily_name,health_pillar_Mental Wellness,health_pillar_Physical Activity,health_pillar_Nutrition
    Morning Meditation,true,false,false
    Evening Walk,false,true,false
    Gratitude Journal,true,false,false
  CSV
  
  File.write('/tmp/test_pillars.csv', pillars_content)
  puts "   ✅ Sample pillars CSV created: /tmp/test_pillars.csv"
rescue => e
  puts "   ❌ Failed to create test files: #{e.message}"
end

# Test 5: Test enqueueing a job (but don't process it)
puts "\n5. Testing Job Enqueueing..."
begin
  job_id = ImportDailiesJob.perform_async('/tmp/test_dailies.csv', { test_mode: true })
  puts "   ✅ Job enqueued successfully with ID: #{job_id}"
  
  # Check if job is in queue
  queue = Sidekiq::Queue.new('default')
  queued_job = queue.find_job(job_id)
  if queued_job
    puts "   ✅ Job found in queue"
    puts "   📋 Job class: #{queued_job.klass}"
    puts "   📁 Job args: #{queued_job.args}"
    
    # Clean up - delete the test job
    queued_job.delete
    puts "   🧹 Test job cleaned up"
  else
    puts "   ⚠️  Job not found in queue (may have been processed immediately)"
  end
rescue => e
  puts "   ❌ Job enqueueing failed: #{e.message}"
end

puts "\n🎉 Sidekiq Setup Test Complete!"
puts "\n📋 Next Steps:"
puts "1. Start Sidekiq worker:"
puts "   bundle exec sidekiq"
puts ""
puts "2. In another terminal, enqueue a real job:"
puts "   rails import:dailies[/tmp/test_dailies.csv]"
puts ""
puts "3. Monitor jobs at:"
puts "   http://localhost:3000/sidekiq"
puts ""
puts "4. View all available import tasks:"
puts "   rails import:help"

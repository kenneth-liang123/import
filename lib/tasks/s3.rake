namespace :s3 do
  desc "Test S3 connection and configuration"
  task test: :environment do
    puts "🧪 Testing S3 Configuration..."
    puts "=" * 40
    
    begin
      service = ActiveStorage::Blob.service
      puts "✅ Active Storage Service: #{service.class}"
      
      if service.is_a?(ActiveStorage::Service::S3Service)
        puts "✅ Using S3 Service"
        puts "📍 Region: #{service.client.config.region}"
        puts "🪣 Bucket: #{service.bucket.name}"
        
        # Test bucket access
        if service.bucket.exists?
          puts "✅ Bucket exists and is accessible"
        else
          puts "❌ Bucket does not exist or is not accessible"
        end
        
        # Test upload capability
        puts "\n🔍 Testing file upload..."
        test_key = "test/#{SecureRandom.uuid}.txt"
        test_content = "Test file content - #{Time.current}"
        
        service.upload(test_key, StringIO.new(test_content), checksum: nil)
        puts "✅ Upload successful"
        
        # Test download
        downloaded_content = service.download(test_key)
        if downloaded_content == test_content
          puts "✅ Download successful"
        else
          puts "❌ Download failed - content mismatch"
        end
        
        # Cleanup
        service.delete(test_key)
        puts "✅ Test file cleaned up"
        
        puts "\n🎉 S3 configuration is working correctly!"
        
      else
        puts "❌ Not using S3 service. Current service: #{service.class}"
        puts "💡 Make sure config.active_storage.service = :amazon in your environment"
      end
      
    rescue => e
      puts "❌ Error testing S3: #{e.message}"
      puts "💡 Check your credentials and bucket configuration"
      puts "🔧 Run: bin/rails s3:setup for configuration help"
    end
  end
  
  desc "Show S3 setup instructions"
  task setup: :environment do
    puts File.read(Rails.root.join('config', 's3_setup.rb'))
  end
  
  desc "Show current S3 configuration"
  task config: :environment do
    puts "📊 Current S3 Configuration:"
    puts "=" * 30
    puts "Environment: #{Rails.env}"
    puts "Storage Service: #{Rails.application.config.active_storage.service}"
    puts "AWS Region: #{ENV['AWS_REGION'] || 'ap-southeast-2'}"
    puts "S3 Bucket: #{ENV['S3_BUCKET'] || 'unleashh'}"
    
    if Rails.application.credentials.dig(:aws, :access_key_id)
      puts "✅ AWS credentials configured in Rails credentials"
    else
      puts "❌ AWS credentials not found in Rails credentials"
      puts "💡 Run: bin/rails credentials:edit"
    end
  end
end

namespace :import do
  desc "Import dailies data from CSV file"
  task :dailies, [ :filepath ] => :environment do |task, args|
    filepath = args[:filepath] || raise("Please provide filepath: rake import:dailies[path/to/file.csv]")

    unless File.exist?(filepath)
      puts "Error: File not found at #{filepath}"
      exit 1
    end

    puts "Starting dailies import from #{filepath}..."
    importer = Importer::Dailies.new(filepath)
    importer.import

    if importer.errors.any?
      puts "Import completed with errors:"
      importer.errors.each { |error| puts "  - #{error}" }
    else
      puts "Import completed successfully!"
    end
  end

  desc "Import daily health pillars data from CSV file"
  task :daily_health_pillars, [ :filepath ] => :environment do |task, args|
    filepath = args[:filepath] || raise("Please provide filepath: rake import:daily_health_pillars[path/to/file.csv]")

    unless File.exist?(filepath)
      puts "Error: File not found at #{filepath}"
      exit 1
    end

    puts "Starting daily health pillars import from #{filepath}..."
    importer = Importer::DailyHealthPillars.new(filepath)
    importer.import

    if importer.errors.any?
      puts "Import completed with errors:"
      importer.errors.each { |error| puts "  - #{error}" }
    else
      puts "Import completed successfully!"
    end
  end

  desc "Download file from S3 and import dailies data"
  task :dailies_from_s3, [ :filename, :bucket ] => :environment do |task, args|
    filename = args[:filename] || raise("Please provide filename: rake import:dailies_from_s3[filename.csv]")
    bucket = args[:bucket] || ENV["AWS_S3_IMPORTERS_BUCKET_NAME"] || "unleashh"

    puts "Downloading #{filename} from S3 bucket #{bucket}..."
    downloader = S3FileDownloader.new(filename, bucket)
    filepath = downloader.download

    puts "Starting dailies import from downloaded file..."
    importer = Importer::Dailies.new(filepath)
    importer.import

    if importer.errors.any?
      puts "Import completed with errors:"
      importer.errors.each { |error| puts "  - #{error}" }
    else
      puts "Import completed successfully!"
    end

    # Clean up downloaded file
    File.delete(filepath) if File.exist?(filepath)
    puts "Cleaned up temporary file"
  end

  desc "Test mode import (dry run) for dailies"
  task :test_dailies, [ :filepath ] => :environment do |task, args|
    filepath = args[:filepath] || raise("Please provide filepath: rake import:test_dailies[path/to/file.csv]")

    unless File.exist?(filepath)
      puts "Error: File not found at #{filepath}"
      exit 1
    end

    puts "Starting TEST MODE dailies import from #{filepath}..."
    importer = Importer::Dailies.new(filepath, test_mode: true)
    importer.import

    if importer.errors.any?
      puts "Test import completed with errors:"
      importer.errors.each { |error| puts "  - #{error}" }
    else
      puts "Test import completed successfully! (No data was actually saved)"
    end
  end
end

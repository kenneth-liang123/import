module Importer
  class Dailies < BaseImporter
    require "csv"

    REQUIRED_HEADERS = [
      "unleash id",
      "daily_name",
      "description",
      "duration_minutes",
      "effort",
      "detailed health benefit",
      "guide",
      "tools"
    ].freeze

    def import
      puts "Processing file..."
      import_dailies
    end

    # Method for Sidekiq job to import a single daily record
    def import_single_daily(row)
      unleash_id = row['unleash id']&.strip
      daily_name = row['daily_name']&.strip
      return if unleash_id.blank? || daily_name.blank?

      daily = Daily.find_or_initialize_by(unleash_id: unleash_id) do |d|
        d.name = daily_name
      end

      # Update all attributes
      daily.assign_attributes({
        name: daily_name,
        description: row['description']&.strip,
        duration_minutes: row['duration_minutes']&.to_i || 0,
        effort: row['effort']&.to_i || 1,
        category: row['category']&.strip,
        step_by_step_guide: row['step_by_step_guide']&.strip,
        scientific_explanation: row['scientific_explanation']&.strip,
        detailed_health_benefit: row['detailed health benefit']&.strip,
        guide: row['guide']&.strip,
        tools: Array.wrap(row['tools']).map { |tool| tool&.strip&.downcase }.compact
      }.compact)

      daily.save! unless test_mode_enabled
      daily
    end

    private

    def import_dailies
      begin
        missing_headers = missing_csv_headers(REQUIRED_HEADERS)
        if missing_headers.present?
          errors << "Required headers missing for Dailies base data. Missing headers -> #{missing_headers.join(",")}. Hence dailies base data and related sub importers will not be imported."
          return
        end

        missing_dailies = []
        puts "Importing dailies..."
        
        CSV.foreach(filepath, headers: true) do |row|
          unleash_id = row["unleash id"]
          name = row["daily_name"]
          description = row["description"]
          duration = row["duration_minutes"].to_i
          effort = row["effort"].to_i
          category = row["category"]
          step_by_step_guide = row["step_by_step_guide"]
          scientific_explanation = row["scientific_explanation"]
          detailed_health_benefit = row["detailed health benefit"]
          guide = row["guide"]
          tools = row["tools"]

          puts "Importing #{unleash_id}..."

          daily = ::Daily.find_by(unleash_id: unleash_id)

          if daily.present?
            puts "FOUND -> Updating daily..."
          else
            missing_dailies << unleash_id
            puts "Creating daily..."
            daily = ::Daily.new(unleash_id: unleash_id)
          end

          unless test_mode_enabled
            daily.assign_attributes({
              name: name,
              description: description,
              duration_minutes: duration,
              effort: effort,
              category: category.presence,
              step_by_step_guide: step_by_step_guide.presence,
              scientific_explanation: scientific_explanation.presence,
              detailed_health_benefit: detailed_health_benefit.presence,
              guide: guide.presence,
              tools: Array.wrap(tools).map { |tool| tool.strip.downcase }
            })
            daily.save!
          end
        end
      rescue CSV::MalformedCSVError => e
        errors << "CSV parsing error: #{e.message}"
        return
      end
      
      puts "#{missing_dailies.size} Missing dailies: #{missing_dailies}"
    end
  end
end

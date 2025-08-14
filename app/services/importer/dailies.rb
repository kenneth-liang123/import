module Importer
  class Dailies < BaseImporter
    require "csv"

    REQUIRED_HEADERS = [
      "name",
      "description",
      "duration",
      "effort",
      "detailed health benefit",
      "guide",
      "tools"
    ].freeze

    def import
      puts "Processing file..."
      import_dailies
    end

    private

    def import_dailies
      missing_headers = missing_csv_headers(REQUIRED_HEADERS)
      if missing_headers.present?
        errors << "Required headers missing for Dailies base data. Missing headers -> #{missing_headers.join(",")}. Hence dailies base data and related sub importers will not be imported."
        return
      end

      missing_dailies = []
      puts "Importing dailies..."
      CSV.foreach(filepath, headers: true) do |row|
        unleash_id = row["unleash id"]
        name = row["name"]
        description = row["description"]
        duration = row["duration"].to_i
        effort = row["effort"].to_i
        health_benefits_description = row["detailed health benefit"]
        guide = row["guide"]
        tools = row["tools"]
        science_rating = row["science rating"]
        goal_match_percentage = row["goal match percentage"]
        coaching = row["coaching"]

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
            health_benefits_description: health_benefits_description.presence,
            guide: guide.presence,
            tools: Array.wrap(tools).map { |tool| tool.strip.downcase },
            # until we add these values to all sheets, we don't want to update them unless they are present
            **(science_rating.present? ? { science_rating: science_rating } : {}),
            **(goal_match_percentage.present? ? { goal_match_percentage: goal_match_percentage } : {}),
            coaching: coaching.presence
          })
          daily.save!
        end
      end
      puts "#{missing_dailies.size} Missing dailies: #{missing_dailies}"
    end
  end
end

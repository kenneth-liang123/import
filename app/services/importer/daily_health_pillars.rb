module Importer
  class DailyHealthPillars < BaseImporter
    require "csv"

    def import
      puts "Processing file..."
      import_dailies_health_pillars
    end

    private

    def import_dailies_health_pillars
      health_pillar_names = HealthPillar.pluck(:name)
      missing_headers = missing_csv_headers(health_pillar_names)
      if missing_headers.present?
        errors << "Required headers missing for Dailies health pillars data. Missing headers -> #{missing_headers.join(",")}. Hence dailies health pillars data not imported."
        return
      end

      missing_dailies = []
      CSV.foreach(filepath, headers: true) do |row|
        unleash_id = row["unleash id"]
        print "Importing daily #{unleash_id}..."
        daily = ::Daily.find_by(unleash_id: unleash_id)

        if daily.present?
          puts "found."
          puts "Clearing existing connections..."
          unless test_mode_enabled
            daily.health_pillars.clear
          end

          HealthPillar.all.each do |health_pillar|
            print "Importing health pillar #{health_pillar.name}..."
            if row[health_pillar.name].blank?
              puts "."
            else
              puts "FOUND -> creating connection"
              unless test_mode_enabled
                ::DailiesHealthPillar.create(
                  daily: daily,
                  health_pillar: health_pillar,
                  quartile: row[health_pillar.name].to_i
                )
              end
            end
          end
        else
          puts "not found."
          missing_dailies << unleash_id
        end
      end
      puts "Missing dailies (#{missing_dailies.size}): #{missing_dailies.join(", ")}"
    end
  end
end

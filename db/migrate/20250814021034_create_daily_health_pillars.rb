class CreateDailyHealthPillars < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_health_pillars do |t|
      t.references :daily, null: false, foreign_key: true
      t.references :health_pillar, null: false, foreign_key: true

      t.timestamps
    end
  end
end

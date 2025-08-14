class CreateHealthPillars < ActiveRecord::Migration[8.0]
  def change
    create_table :health_pillars do |t|
      t.string :name
      t.text :description

      t.timestamps
    end
    add_index :health_pillars, :name, unique: true
  end
end

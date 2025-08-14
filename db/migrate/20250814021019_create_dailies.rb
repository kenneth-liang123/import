class CreateDailies < ActiveRecord::Migration[8.0]
  def change
    create_table :dailies do |t|
      t.string :unleash_id
      t.string :name
      t.text :description
      t.integer :duration_minutes
      t.integer :effort
      t.string :category
      t.text :step_by_step_guide
      t.text :scientific_explanation
      t.text :detailed_health_benefit
      t.text :guide
      t.text :tools

      t.timestamps
    end
    add_index :dailies, :unleash_id, unique: true
  end
end

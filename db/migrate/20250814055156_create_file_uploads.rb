class CreateFileUploads < ActiveRecord::Migration[8.0]
  def change
    create_table :file_uploads do |t|
      t.string :filename
      t.string :file_type
      t.string :status
      t.string :import_type
      t.string :user_email
      t.string :job_id
      t.text :error_message
      t.datetime :processed_at

      t.timestamps
    end
  end
end

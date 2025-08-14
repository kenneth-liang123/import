# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_14_055210) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "dailies", force: :cascade do |t|
    t.string "unleash_id"
    t.string "name"
    t.text "description"
    t.integer "duration_minutes"
    t.integer "effort"
    t.string "category"
    t.text "step_by_step_guide"
    t.text "scientific_explanation"
    t.text "detailed_health_benefit"
    t.text "guide"
    t.text "tools"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["unleash_id"], name: "index_dailies_on_unleash_id", unique: true
  end

  create_table "daily_health_pillars", force: :cascade do |t|
    t.bigint "daily_id", null: false
    t.bigint "health_pillar_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["daily_id"], name: "index_daily_health_pillars_on_daily_id"
    t.index ["health_pillar_id"], name: "index_daily_health_pillars_on_health_pillar_id"
  end

  create_table "file_uploads", force: :cascade do |t|
    t.string "filename"
    t.string "file_type"
    t.string "status"
    t.string "import_type"
    t.string "user_email"
    t.string "job_id"
    t.text "error_message"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "health_pillars", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_health_pillars_on_name", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "daily_health_pillars", "dailies"
  add_foreign_key "daily_health_pillars", "health_pillars"
end

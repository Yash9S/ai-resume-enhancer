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

ActiveRecord::Schema[8.0].define(version: 2025_10_21_031236) do
  create_schema "acme"
  create_schema "globalsol"
  create_schema "techstart"
  create_schema "test"

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "uuid-ossp"

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

  create_table "job_descriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.text "content"
    t.string "company_name"
    t.string "location"
    t.json "extracted_keywords"
    t.json "requirements"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "employment_type"
    t.string "experience_level"
    t.string "salary_range"
    t.text "required_skills"
    t.string "company"
    t.text "description"
    t.index ["created_at"], name: "index_job_descriptions_on_created_at"
    t.index ["user_id"], name: "index_job_descriptions_on_user_id"
  end

  create_table "resume_processings", force: :cascade do |t|
    t.bigint "resume_id", null: false
    t.bigint "job_description_id"
    t.bigint "user_id", null: false
    t.integer "processing_type", null: false
    t.integer "status", default: 0, null: false
    t.text "result"
    t.text "error_message"
    t.json "ai_response"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.float "match_score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_resume_processings_on_created_at"
    t.index ["job_description_id"], name: "index_resume_processings_on_job_description_id"
    t.index ["processing_type"], name: "index_resume_processings_on_processing_type"
    t.index ["resume_id"], name: "index_resume_processings_on_resume_id"
    t.index ["status"], name: "index_resume_processings_on_status"
    t.index ["user_id"], name: "index_resume_processings_on_user_id"
  end

  create_table "resumes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.text "original_content"
    t.text "extracted_content"
    t.text "enhanced_content"
    t.integer "status", default: 0, null: false
    t.json "extracted_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "processing_status", default: 0
    t.datetime "processing_started_at"
    t.datetime "processing_completed_at"
    t.text "processing_error"
    t.string "ai_provider_used"
    t.string "extracted_name"
    t.string "extracted_email"
    t.string "extracted_phone"
    t.string "extracted_location"
    t.text "extracted_summary"
    t.text "extracted_skills"
    t.text "extracted_experience"
    t.text "extracted_education"
    t.text "extracted_text"
    t.decimal "extraction_confidence", precision: 5, scale: 2
    t.index ["created_at"], name: "index_resumes_on_created_at"
    t.index ["processing_status", "created_at"], name: "index_resumes_on_processing_status_and_created_at"
    t.index ["processing_status"], name: "index_resumes_on_processing_status"
    t.index ["status"], name: "index_resumes_on_status"
    t.index ["user_id"], name: "index_resumes_on_user_id"
  end

  create_table "tenants", force: :cascade do |t|
    t.string "name", null: false
    t.string "subdomain", null: false
    t.string "schema_name", null: false
    t.string "status", default: "active"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["schema_name"], name: "index_tenants_on_schema_name", unique: true
    t.index ["status"], name: "index_tenants_on_status"
    t.index ["subdomain"], name: "index_tenants_on_subdomain", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "role", default: 0, null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "tenant_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["tenant_id"], name: "index_users_on_tenant_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "job_descriptions", "users"
  add_foreign_key "resume_processings", "job_descriptions"
  add_foreign_key "resume_processings", "resumes"
  add_foreign_key "resume_processings", "users"
  add_foreign_key "users", "tenants"
end

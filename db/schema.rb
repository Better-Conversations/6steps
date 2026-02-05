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

ActiveRecord::Schema[8.0].define(version: 2026_02_03_200932) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "consents", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "consent_type"
    t.string "version"
    t.datetime "given_at"
    t.string "ip_address"
    t.datetime "withdrawn_at"
    t.string "withdrawal_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_consents_on_user_id"
  end

  create_table "invites", force: :cascade do |t|
    t.string "token", null: false
    t.string "email"
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.bigint "created_by_id"
    t.bigint "used_by_id"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "multi_use", default: false, null: false
    t.integer "max_uses"
    t.integer "use_count", default: 0, null: false
    t.index ["created_by_id"], name: "index_invites_on_created_by_id"
    t.index ["email"], name: "index_invites_on_email"
    t.index ["token"], name: "index_invites_on_token", unique: true
    t.index ["used_by_id"], name: "index_invites_on_used_by_id"
  end

  create_table "journey_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "state", default: 0, null: false
    t.string "current_space"
    t.integer "iteration_count", default: 0, null: false
    t.float "current_depth_score", default: 0.0, null: false
    t.datetime "started_at"
    t.boolean "soft_time_limit_warned", default: false, null: false
    t.text "session_summary"
    t.text "pending_question"
    t.string "reflected_words_cache"
    t.integer "grounding_insertions_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["state"], name: "index_journey_sessions_on_state"
    t.index ["user_id", "state"], name: "index_journey_sessions_on_user_id_and_state"
    t.index ["user_id"], name: "index_journey_sessions_on_user_id"
  end

  create_table "safety_audit_logs", force: :cascade do |t|
    t.bigint "journey_session_id", null: false
    t.integer "event_type"
    t.jsonb "trigger_data"
    t.float "depth_score_snapshot"
    t.string "response_taken"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["journey_session_id"], name: "index_safety_audit_logs_on_journey_session_id"
  end

  create_table "session_iterations", force: :cascade do |t|
    t.bigint "journey_session_id", null: false
    t.integer "iteration_number"
    t.text "question_asked"
    t.text "user_response"
    t.string "reflected_words"
    t.string "space_explored"
    t.float "depth_score_at_end"
    t.string "safety_intervention"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["journey_session_id"], name: "index_session_iterations_on_journey_session_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "region", default: 0, null: false
    t.string "timezone", default: "UTC"
    t.integer "role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "consents", "users"
  add_foreign_key "invites", "users", column: "created_by_id"
  add_foreign_key "invites", "users", column: "used_by_id"
  add_foreign_key "journey_sessions", "users"
  add_foreign_key "safety_audit_logs", "journey_sessions"
  add_foreign_key "session_iterations", "journey_sessions"
end

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

ActiveRecord::Schema[8.1].define(version: 2026_05_29_155646) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "api_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.integer "organization_id", null: false
    t.datetime "revoked_at"
    t.string "role", default: "owner", null: false
    t.json "scopes_json", default: [], null: false
    t.string "token_digest", null: false
    t.string "token_hint", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_api_keys_on_organization_id"
    t.index ["token_digest"], name: "index_api_keys_on_token_digest", unique: true
    t.check_constraint "role::text = ANY (ARRAY['owner'::character varying, 'operator'::character varying, 'viewer'::character varying]::text[])", name: "api_keys_role_valid"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.integer "api_key_id"
    t.string "correlation_id"
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.json "metadata_json", default: {}, null: false
    t.integer "organization_id", null: false
    t.string "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["api_key_id"], name: "index_audit_logs_on_api_key_id"
    t.index ["organization_id", "created_at"], name: "index_audit_logs_on_organization_id_and_created_at"
    t.index ["organization_id"], name: "index_audit_logs_on_organization_id"
    t.index ["subject_type", "subject_id"], name: "index_audit_logs_on_subject_type_and_subject_id"
  end

  create_table "credentials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.datetime "last_used_at"
    t.json "metadata_json", default: {}, null: false
    t.string "name", null: false
    t.integer "organization_id", null: false
    t.text "secret_ciphertext", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "name"], name: "index_credentials_on_organization_id_and_name", unique: true
    t.index ["organization_id"], name: "index_credentials_on_organization_id"
    t.check_constraint "kind::text = ANY (ARRAY['api_key'::character varying, 'bearer_token'::character varying, 'basic_auth'::character varying, 'webhook_secret'::character varying]::text[])", name: "credentials_kind_valid"
  end

  create_table "dead_letters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "node_execution_id"
    t.integer "organization_id", null: false
    t.json "payload_json", default: {}, null: false
    t.string "reason", null: false
    t.datetime "resolved_at"
    t.integer "retry_count", default: 0, null: false
    t.string "status", default: "open", null: false
    t.datetime "updated_at", null: false
    t.integer "workflow_execution_id", null: false
    t.index ["node_execution_id"], name: "index_dead_letters_on_node_execution_id"
    t.index ["organization_id", "status"], name: "index_dead_letters_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_dead_letters_on_organization_id"
    t.index ["workflow_execution_id"], name: "index_dead_letters_on_workflow_execution_id"
    t.check_constraint "retry_count >= 0", name: "dead_letters_retry_count_non_negative"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'retried'::character varying, 'resolved'::character varying]::text[])", name: "dead_letters_status_valid"
  end

  create_table "node_executions", force: :cascade do |t|
    t.integer "attempt", default: 1, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.json "error_json", default: {}, null: false
    t.json "input_json", default: {}, null: false
    t.string "node_key", null: false
    t.string "node_type", null: false
    t.json "output_json", default: {}, null: false
    t.datetime "started_at", null: false
    t.string "status", default: "running", null: false
    t.datetime "updated_at", null: false
    t.integer "workflow_execution_id", null: false
    t.index ["workflow_execution_id", "node_key", "attempt"], name: "index_node_executions_on_execution_node_attempt", unique: true
    t.index ["workflow_execution_id"], name: "index_node_executions_on_workflow_execution_id"
    t.check_constraint "attempt > 0", name: "node_executions_attempt_positive"
    t.check_constraint "status::text = ANY (ARRAY['running'::character varying, 'succeeded'::character varying, 'failed'::character varying, 'skipped'::character varying]::text[])", name: "node_executions_status_valid"
  end

  create_table "operator_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.string "role", default: "operator", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["organization_id", "user_id"], name: "index_operator_memberships_on_organization_id_and_user_id", unique: true
    t.index ["organization_id"], name: "index_operator_memberships_on_organization_id"
    t.index ["user_id"], name: "index_operator_memberships_on_user_id"
    t.check_constraint "role::text = ANY (ARRAY['owner'::character varying, 'operator'::character varying, 'viewer'::character varying]::text[])", name: "operator_memberships_role_valid"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "metadata_json", default: {}, null: false
    t.string "name", null: false
    t.string "plan", default: "launch", null: false
    t.integer "rate_limit_per_minute", default: 120, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
    t.check_constraint "rate_limit_per_minute > 0", name: "organizations_rate_limit_positive"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "webhook_events", force: :cascade do |t|
    t.string "correlation_id", null: false
    t.datetime "created_at", null: false
    t.json "headers_json", default: {}, null: false
    t.string "idempotency_key", null: false
    t.integer "organization_id", null: false
    t.json "payload_json", default: {}, null: false
    t.datetime "received_at", null: false
    t.string "source_event_id"
    t.string "status", default: "accepted", null: false
    t.datetime "updated_at", null: false
    t.integer "workflow_version_id", null: false
    t.index ["organization_id", "received_at"], name: "index_webhook_events_on_organization_id_and_received_at"
    t.index ["organization_id"], name: "index_webhook_events_on_organization_id"
    t.index ["workflow_version_id", "idempotency_key"], name: "index_webhook_events_on_version_and_idempotency", unique: true
    t.index ["workflow_version_id"], name: "index_webhook_events_on_workflow_version_id"
    t.check_constraint "status::text = ANY (ARRAY['accepted'::character varying, 'duplicate'::character varying, 'rejected'::character varying]::text[])", name: "webhook_events_status_valid"
  end

  create_table "workflow_executions", force: :cascade do |t|
    t.integer "attempt_count", default: 0, null: false
    t.datetime "completed_at"
    t.string "correlation_id", null: false
    t.datetime "created_at", null: false
    t.json "error_json", default: {}, null: false
    t.string "idempotency_key", null: false
    t.json "input_json", default: {}, null: false
    t.integer "organization_id", null: false
    t.datetime "started_at"
    t.string "status", default: "queued", null: false
    t.datetime "updated_at", null: false
    t.integer "webhook_event_id"
    t.integer "workflow_id", null: false
    t.integer "workflow_version_id", null: false
    t.index ["organization_id", "status"], name: "index_workflow_executions_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_workflow_executions_on_organization_id"
    t.index ["webhook_event_id"], name: "index_workflow_executions_on_webhook_event_id"
    t.index ["workflow_id"], name: "index_workflow_executions_on_workflow_id"
    t.index ["workflow_version_id", "idempotency_key"], name: "index_workflow_executions_on_version_and_idempotency", unique: true
    t.index ["workflow_version_id"], name: "index_workflow_executions_on_workflow_version_id"
    t.check_constraint "attempt_count >= 0", name: "workflow_executions_attempt_count_non_negative"
    t.check_constraint "status::text = ANY (ARRAY['queued'::character varying, 'running'::character varying, 'retrying'::character varying, 'succeeded'::character varying, 'failed'::character varying, 'canceled'::character varying]::text[])", name: "workflow_executions_status_valid"
  end

  create_table "workflow_versions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "graph_checksum", null: false
    t.json "graph_json", default: {}, null: false
    t.integer "organization_id", null: false
    t.datetime "published_at", null: false
    t.json "retry_policy_json", default: {}, null: false
    t.string "trigger_key", null: false
    t.datetime "updated_at", null: false
    t.integer "version_number", null: false
    t.text "webhook_secret_ciphertext", null: false
    t.integer "workflow_id", null: false
    t.index ["organization_id", "graph_checksum"], name: "index_workflow_versions_on_organization_id_and_graph_checksum"
    t.index ["organization_id"], name: "index_workflow_versions_on_organization_id"
    t.index ["trigger_key"], name: "index_workflow_versions_on_trigger_key", unique: true
    t.index ["workflow_id", "version_number"], name: "index_workflow_versions_on_workflow_id_and_version_number", unique: true
    t.index ["workflow_id"], name: "index_workflow_versions_on_workflow_id"
  end

  create_table "workflows", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.json "metadata_json", default: {}, null: false
    t.string "name", null: false
    t.integer "organization_id", null: false
    t.string "slug", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "slug"], name: "index_workflows_on_organization_id_and_slug", unique: true
    t.index ["organization_id"], name: "index_workflows_on_organization_id"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'active'::character varying, 'archived'::character varying]::text[])", name: "workflows_status_valid"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_keys", "organizations"
  add_foreign_key "audit_logs", "api_keys"
  add_foreign_key "audit_logs", "organizations"
  add_foreign_key "credentials", "organizations"
  add_foreign_key "dead_letters", "node_executions"
  add_foreign_key "dead_letters", "organizations"
  add_foreign_key "dead_letters", "workflow_executions"
  add_foreign_key "node_executions", "workflow_executions"
  add_foreign_key "operator_memberships", "organizations"
  add_foreign_key "operator_memberships", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "webhook_events", "organizations"
  add_foreign_key "webhook_events", "workflow_versions"
  add_foreign_key "workflow_executions", "organizations"
  add_foreign_key "workflow_executions", "webhook_events"
  add_foreign_key "workflow_executions", "workflow_versions"
  add_foreign_key "workflow_executions", "workflows"
  add_foreign_key "workflow_versions", "organizations"
  add_foreign_key "workflow_versions", "workflows"
  add_foreign_key "workflows", "organizations"
end

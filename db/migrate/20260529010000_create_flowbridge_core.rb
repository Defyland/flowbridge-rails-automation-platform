class CreateFlowbridgeCore < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :plan, null: false, default: "launch"
      t.integer :rate_limit_per_minute, null: false, default: 120
      t.json :metadata_json, null: false, default: {}

      t.timestamps
    end
    add_index :organizations, :slug, unique: true
    add_check_constraint :organizations, "rate_limit_per_minute > 0", name: "organizations_rate_limit_positive"

    create_table :api_keys do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :token_hint, null: false
      t.string :role, null: false, default: "owner"
      t.json :scopes_json, null: false, default: []
      t.datetime :last_used_at
      t.datetime :revoked_at

      t.timestamps
    end
    add_index :api_keys, :token_digest, unique: true
    add_check_constraint :api_keys, "role IN ('owner', 'operator', 'viewer')", name: "api_keys_role_valid"

    create_table :workflows do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :status, null: false, default: "draft"
      t.text :description
      t.json :metadata_json, null: false, default: {}

      t.timestamps
    end
    add_index :workflows, [ :organization_id, :slug ], unique: true
    add_check_constraint :workflows, "status IN ('draft', 'active', 'archived')", name: "workflows_status_valid"

    create_table :workflow_versions do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :workflow, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.string :trigger_key, null: false
      t.text :webhook_secret_ciphertext, null: false
      t.json :graph_json, null: false, default: {}
      t.string :graph_checksum, null: false
      t.json :retry_policy_json, null: false, default: {}
      t.datetime :published_at, null: false

      t.timestamps
    end
    add_index :workflow_versions, [ :workflow_id, :version_number ], unique: true
    add_index :workflow_versions, :trigger_key, unique: true
    add_index :workflow_versions, [ :organization_id, :graph_checksum ]

    create_table :credentials do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :kind, null: false
      t.text :secret_ciphertext, null: false
      t.json :metadata_json, null: false, default: {}
      t.datetime :last_used_at

      t.timestamps
    end
    add_index :credentials, [ :organization_id, :name ], unique: true
    add_check_constraint :credentials, "kind IN ('api_key', 'bearer_token', 'basic_auth', 'webhook_secret')", name: "credentials_kind_valid"

    create_table :webhook_events do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :workflow_version, null: false, foreign_key: true
      t.string :idempotency_key, null: false
      t.string :source_event_id
      t.string :status, null: false, default: "accepted"
      t.string :correlation_id, null: false
      t.json :payload_json, null: false, default: {}
      t.json :headers_json, null: false, default: {}
      t.datetime :received_at, null: false

      t.timestamps
    end
    add_index :webhook_events, [ :workflow_version_id, :idempotency_key ], unique: true, name: "index_webhook_events_on_version_and_idempotency"
    add_index :webhook_events, [ :organization_id, :received_at ]
    add_check_constraint :webhook_events, "status IN ('accepted', 'duplicate', 'rejected')", name: "webhook_events_status_valid"

    create_table :workflow_executions do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :workflow, null: false, foreign_key: true
      t.references :workflow_version, null: false, foreign_key: true
      t.references :webhook_event, null: true, foreign_key: true
      t.string :status, null: false, default: "queued"
      t.integer :attempt_count, null: false, default: 0
      t.string :correlation_id, null: false
      t.string :idempotency_key, null: false
      t.json :input_json, null: false, default: {}
      t.json :error_json, null: false, default: {}
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
    add_index :workflow_executions, [ :workflow_version_id, :idempotency_key ], unique: true, name: "index_workflow_executions_on_version_and_idempotency"
    add_index :workflow_executions, [ :organization_id, :status ]
    add_check_constraint :workflow_executions, "status IN ('queued', 'running', 'retrying', 'succeeded', 'failed', 'canceled')", name: "workflow_executions_status_valid"
    add_check_constraint :workflow_executions, "attempt_count >= 0", name: "workflow_executions_attempt_count_non_negative"

    create_table :node_executions do |t|
      t.references :workflow_execution, null: false, foreign_key: true
      t.string :node_key, null: false
      t.string :node_type, null: false
      t.string :status, null: false, default: "running"
      t.integer :attempt, null: false, default: 1
      t.json :input_json, null: false, default: {}
      t.json :output_json, null: false, default: {}
      t.json :error_json, null: false, default: {}
      t.integer :duration_ms
      t.datetime :started_at, null: false
      t.datetime :completed_at

      t.timestamps
    end
    add_index :node_executions, [ :workflow_execution_id, :node_key, :attempt ], unique: true, name: "index_node_executions_on_execution_node_attempt"
    add_check_constraint :node_executions, "status IN ('running', 'succeeded', 'failed', 'skipped')", name: "node_executions_status_valid"
    add_check_constraint :node_executions, "attempt > 0", name: "node_executions_attempt_positive"

    create_table :dead_letters do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :workflow_execution, null: false, foreign_key: true
      t.references :node_execution, null: true, foreign_key: true
      t.string :status, null: false, default: "open"
      t.string :reason, null: false
      t.json :payload_json, null: false, default: {}
      t.integer :retry_count, null: false, default: 0
      t.datetime :resolved_at

      t.timestamps
    end
    add_index :dead_letters, [ :organization_id, :status ]
    add_check_constraint :dead_letters, "status IN ('open', 'retried', 'resolved')", name: "dead_letters_status_valid"
    add_check_constraint :dead_letters, "retry_count >= 0", name: "dead_letters_retry_count_non_negative"

    create_table :audit_logs do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :api_key, null: true, foreign_key: true
      t.string :action, null: false
      t.string :subject_type, null: false
      t.string :subject_id, null: false
      t.string :correlation_id
      t.string :ip_address
      t.json :metadata_json, null: false, default: {}

      t.timestamps
    end
    add_index :audit_logs, [ :organization_id, :created_at ]
    add_index :audit_logs, [ :subject_type, :subject_id ]
  end
end

class CreateOperatorMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :operator_memberships do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "operator"

      t.timestamps
    end

    add_index :operator_memberships, [ :organization_id, :user_id ], unique: true
    add_check_constraint :operator_memberships, "role IN ('owner', 'operator', 'viewer')", name: "operator_memberships_role_valid"
  end
end

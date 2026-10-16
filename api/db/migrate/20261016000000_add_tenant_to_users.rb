# frozen_string_literal: true

# A user belongs to one organization (tenant). Login derives the token's tenant from this column,
# never from a request header (audit R-02).
class AddTenantToUsers < ActiveRecord::Migration[7.0]
  def up
    add_column :users, :tenant_id, :bigint
    add_index :users, :tenant_id, name: 'idx_ai_interview_users_tenant'

    # Existing users predate multi-tenancy. If there is exactly one real organization they unambiguously belong
    # to it; otherwise they stay unassigned and cannot log in until an operator assigns them.
    execute <<~SQL.squish
      UPDATE users
      SET tenant_id = (SELECT id FROM organizations WHERE id <> 0 LIMIT 1)
      WHERE tenant_id IS NULL
        AND (SELECT COUNT(*) FROM organizations WHERE id <> 0) = 1
    SQL
  end

  def down
    remove_index :users, name: 'idx_ai_interview_users_tenant'
    remove_column :users, :tenant_id
  end
end

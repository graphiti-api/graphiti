# This migration comes from budget_audit_api (originally 20160620170742)
class CreateBudgetAuditApiBudgets < ActiveRecord::Migration[5.0]
  def change
    create_table :budget_audit_api_budgets do |t|
      t.json :item
      t.json :storages, array: true, default: []
      t.json :networks, array: true, default: []

      t.timestamps
    end
  end
end

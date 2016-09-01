# This migration comes from budget_audit_api (originally 20160622202719)
class AddItemIdToBudget < ActiveRecord::Migration[5.0]
  def change
    add_column :budget_audit_api_budgets, :backend_id,        :string, null: false
    add_column :budget_audit_api_budgets, :updated_user_name, :string, null: false
    add_column :budget_audit_api_budgets, :updated_user_uuid, :string, null: false
  end
end

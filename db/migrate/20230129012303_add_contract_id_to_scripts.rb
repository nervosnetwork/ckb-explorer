class AddContractIdToScripts < ActiveRecord::Migration[7.0]
  def change
    add_column :scripts, :contract_id, :bigint
  end
end

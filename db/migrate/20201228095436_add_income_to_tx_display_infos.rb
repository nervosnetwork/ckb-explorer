class AddIncomeToTxDisplayInfos < ActiveRecord::Migration[6.0]
  def change
    add_column :tx_display_infos, :income, :jsonb
  end
end

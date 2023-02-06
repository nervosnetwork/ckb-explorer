class AddIssuanceToBlockStatistic < ActiveRecord::Migration[7.0]
  def change
    add_column :block_statistics, :primary_issuance, :decimal, precision: 36, scale: 18, default: "0.0"
    add_column :block_statistics, :secondary_issuance, :decimal, precision: 36, scale: 18, default: "0.0"
  end
end

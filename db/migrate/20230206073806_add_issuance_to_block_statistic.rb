class AddIssuanceToBlockStatistic < ActiveRecord::Migration[7.0]
  def change
    add_column :block_statistics, :primary_issuance, :decimal, precision: 36, scale: 8
    add_column :block_statistics, :secondary_issuance, :decimal, precision: 36, scale: 8
    add_column :block_statistics, :total_issuance, :decimal, precision: 36, scale: 8, comment: "C_i in DAO header (accumulated deposits)"
    add_column :block_statistics, :accumulated_rate, :decimal, precision: 36, scale: 8, comment: "AR_i in DAO header"
    add_column :block_statistics, :unissued_secondary_issuance, :decimal, precision: 36, scale: 8, comment: "S_i in DAO header"
    add_column :block_statistics, :total_occupied_capacities, :decimal, precision: 36, scale: 8, comment: "U_i in DAO header"
  end
end

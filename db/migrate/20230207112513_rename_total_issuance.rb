class RenameTotalIssuance < ActiveRecord::Migration[7.0]
  def change
    rename_column :block_statistics, :total_issuance, :accumulated_total_deposits
    # Ex:- rename_column("admin_users", "pasword","hashed_pasword")
  end
end

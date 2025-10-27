class RemoveDaoTxCountOfAddress < ActiveRecord::Migration[7.0]
  def change
    remove_columns :addresses, :dao_transactions_count, type: :bigint
  end
end

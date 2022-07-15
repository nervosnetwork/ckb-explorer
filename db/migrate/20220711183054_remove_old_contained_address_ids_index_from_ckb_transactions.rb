class RemoveOldContainedAddressIdsIndexFromCkbTransactions < ActiveRecord::Migration[6.1]
  def change
    remove_index :ckb_transactions, :contained_address_ids
  end
end

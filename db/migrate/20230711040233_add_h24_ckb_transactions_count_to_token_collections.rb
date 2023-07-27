class AddH24CkbTransactionsCountToTokenCollections < ActiveRecord::Migration[7.0]
  def up
    add_column :token_collections, :h24_ckb_transactions_count, :bigint, default: 0

    TokenCollection.find_each do |collection|
      h24_ckb_transactions_count =
        Rails.cache.realize("collection_h24_ckb_transactions_count_#{collection.id}", expires_in: 1.hour) do
          timestamp = CkbUtils.time_in_milliseconds(24.hours.ago)
          h24_transfers = collection.transfers.joins(:ckb_transaction).where("ckb_transactions.block_timestamp >= ?",
                                                                             timestamp)
          h24_transfers.distinct.count(:transaction_id)
        end

      collection.update_column(:h24_ckb_transactions_count, h24_ckb_transactions_count)
    end
  end

  def down
    remove_column :token_collections, :h24_ckb_transactions_count
  end
end

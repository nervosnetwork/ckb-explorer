namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fix_address_tx_count"
  task check_address_info: :environment do
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")
    AddressBlockSnapshot.select(:address_id).distinct.find_each(batch_size: 1000) do |snapshot|
      puts snapshot.address_id
      address = Address.find(snapshot.address_id)
      local_tip_block = Block.recent.first
      address.update(
        ckb_transactions_count: AccountBook.where(address_id: address.id).where("block_number <= ?", local_tip_block.number).count,
        dao_transactions_count: DaoEvent.processed.where(address_id: address.id).where("block_timestamp <= ?", local_tip_block.timestamp).distinct.count(:ckb_transaction_id),
        last_updated_block_number: local_tip_block.number,
      )
      AddressBlockSnapshot.where(address_id: address.id).delete_all
      puts "done"
    end
  end
end

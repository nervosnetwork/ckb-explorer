namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fix_address_tx_count"
  task fix_address_tx_count: :environment do
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")
    subquery = AddressBlockSnapshot.select(:address_id).distinct.order(:address_id)
    Address.where(id: subquery).find_each do |address|
      puts address.id
      local_tip_block = Block.recent.first
      address.update(
        ckb_transactions_count: AccountBook.where(address_id: address.id).where("block_number <= ?", local_tip_block.number).count,
        dao_transactions_count: DaoEvent.processed.where(address_id: address.id).where("block_timestamp <= ?", local_tip_block.timestamp).distinct.count(:ckb_transaction_id),
        last_updated_block_number: local_tip_block.number,
      )
      AddressBlockSnapshot.where(address_id: address.id).delete_all
    end
    puts "done"
  end
end

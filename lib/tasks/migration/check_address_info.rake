namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:check_address_info"
  task check_address_info: :environment do
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")
    Address.where(last_updated_block_number: nil).find_each do |address|
      puts "#{Time.now}-#{address.id}"
      if address.last_updated_block_number.nil?
        local_tip_block = Block.recent.first
        address.last_updated_block_number = local_tip_block.number
        address.live_cells_count = address.cell_outputs.live.where("block_timestamp <= ?", local_tip_block.timestamp).count
        address.ckb_transactions_count = AccountBook.where(address_id: address.id).where("block_number <= ?", local_tip_block.number).count
        address.dao_transactions_count = DaoEvent.processed.where(address_id: address.id).where("block_timestamp <= ?", local_tip_block.timestamp).distinct.count(:ckb_transaction_id)
        address.cal_balance!
        address.save!
      end
    end
    puts "done"
  end
end

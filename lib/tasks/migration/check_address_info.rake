namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:check_address_info"
  task check_address_info: :environment do
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")
    Address.joins(:account_books).where(last_updated_block_number: nil).where.not(account_books: { block_number: nil }).find_each do |address|
      if address.last_updated_block_number.nil?
        account_book = AccountBook.where(address_id: address.id).select(:block_number).order("block_number desc").limit(1)
        address.last_updated_block_number = account_book.first.block_number
        address.live_cells_count = address.cell_outputs.live.count
        address.ckb_transactions_count = AccountBook.where(address_id: address.id).count
        address.dao_transactions_count = DaoEvent.processed.where(address_id: address.id).distinct(:ckb_transaction_id).count
        address.cal_balance!
        address.save!
      end
    end
    puts "done"
  end
end

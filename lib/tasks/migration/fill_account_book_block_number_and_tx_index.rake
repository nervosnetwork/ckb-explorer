namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_account_book_block_number_and_tx_index"
  task fill_account_book_block_number_and_tx_index: :environment do
    AccountBook.where(block_number: nil).order("ckb_transaction_id asc").find_in_batches do |group|
      attrs = []
      group.group_by { |r| r.ckb_transaction_id }.each do |ckb_transaction_id, records|
        tx = CkbTransaction.includes(:inputs, :outputs).find_by(id: ckb_transaction_id)
        if tx.present?
          records.each do |r|
            income = tx.outputs.where(address_id: r.address_id).sum(:capacity) - tx.inputs.where(address_id: r.address_id).sum(:capacity)
            attrs << { address_id: r.address_id, ckb_transaction_id:, income:, block_number: tx.block_number, tx_index: tx.tx_index }
          end
        end
      end
      AccountBook.upsert_all(attrs, unique_by: %i[address_id ckb_transaction_id])
    end
    puts "done"
  end
end

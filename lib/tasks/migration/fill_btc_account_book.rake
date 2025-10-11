namespace :migration do
  task fill_btc_account_book: :environment do
    BitcoinAddressMapping.find_in_batches.with_index do |group, batch|
      puts "Processing group ##{batch}"
      group.each do |address_mapping|
        ckb_address_id = address_mapping.ckb_address_id
        bitcoin_address_id = address_mapping.bitcoin_address_id
        ckb_transaction_id = AccountBook.where(address_id: ckb_address_id).limit(1).ckb_transaction_id

        BtcAccountBook.find_or_create_by!(ckb_transaction_id: cell_output.ckb_transaction_id, bitcoin_address_id: bitcoin_address.id)
        Rails.cache.write("fill_btc_account_book_job", address_mapping.id)
      end
    end
  end
end

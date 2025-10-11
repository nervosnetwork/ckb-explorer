class BtcAccountBook < ApplicationRecord
end

# == Schema Information
#
# Table name: btc_account_books
#
#  id                 :bigint           not null, primary key
#  ckb_transaction_id :bigint
#  bitcoin_address_id :bigint
#
# Indexes
#
#  index_btc_account_books_on_bitcoin_address_id  (bitcoin_address_id)
#

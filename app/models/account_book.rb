# save the relationship between address and transaction
class AccountBook < ApplicationRecord
  belongs_to :address
  belongs_to :ckb_transaction
end

# == Schema Information
#
# Table name: account_books
#
#  id                 :bigint           not null, primary key
#  address_id         :bigint
#  ckb_transaction_id :bigint
#  income             :decimal(30, )
#  block_number       :bigint
#  tx_index           :integer
#
# Indexes
#
#  index_account_books_on_address_id_and_ckb_transaction_id  (address_id,ckb_transaction_id) UNIQUE
#  index_account_books_on_block_number_and_tx_index          (block_number,tx_index)
#  index_account_books_on_ckb_transaction_id                 (ckb_transaction_id)
#

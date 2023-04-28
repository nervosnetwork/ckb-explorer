# save the relationship of dao transactions in address
class AddressDaoTransaction < ApplicationRecord
end

# == Schema Information
#
# Table name: address_dao_transactions
#
#  ckb_transaction_id :bigint
#  address_id         :bigint
#
# Indexes
#
#  address_dao_tx_alt_pk                                 (address_id,ckb_transaction_id) UNIQUE
#  index_address_dao_transactions_on_ckb_transaction_id  (ckb_transaction_id)
#

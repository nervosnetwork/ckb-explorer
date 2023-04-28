# save the relationship of udt-related transactions in address
class AddressUdtTransaction < ApplicationRecord
end

# == Schema Information
#
# Table name: address_udt_transactions
#
#  ckb_transaction_id :bigint
#  address_id         :bigint
#
# Indexes
#
#  address_udt_tx_alt_pk                                 (address_id,ckb_transaction_id) UNIQUE
#  index_address_udt_transactions_on_ckb_transaction_id  (ckb_transaction_id)
#

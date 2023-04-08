class TransactionAddressChange < ApplicationRecord
  belongs_to :ckb_transaction
  belongs_to :address
end

# == Schema Information
#
# Table name: transaction_address_changes
#
#  id                 :bigint           not null, primary key
#  ckb_transaction_id :bigint           not null
#  address_id         :bigint           not null
#  name               :string           not null
#  delta              :decimal(, )      default(0.0), not null
#
# Indexes
#
#  index_transaction_address_changes_on_ckb_transaction_id  (ckb_transaction_id)
#  tx_address_changes_alt_pk                                (address_id,ckb_transaction_id,name) UNIQUE
#

class AddressDaoTransaction < ApplicationRecord
end

# == Schema Information
#
# Table name: address_dao_transactions
#
#  ckb_transaction_id :bigint
#  address_id         :bigint
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  altpk                                                 (address_id,ckb_transaction_id) UNIQUE
#  index_address_dao_transactions_on_ckb_transaction_id  (ckb_transaction_id)
#

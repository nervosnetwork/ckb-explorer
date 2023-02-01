# intermediate table between udt and transaction
class UdtTransaction < ApplicationRecord
end

# == Schema Information
#
# Table name: udt_transactions
#
#  udt_id             :bigint
#  ckb_transaction_id :bigint
#
# Indexes
#
#  index_udt_transactions_on_ckb_transaction_id  (ckb_transaction_id)
#  index_udt_transactions_on_udt_id              (udt_id)
#  pk                                            (udt_id,ckb_transaction_id) UNIQUE
#

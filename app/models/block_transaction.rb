# save the relationship between transaction and block
# tell us which transaction is in which block
# because a transaction can be included in different blocks
# but only one block can be included in chain
class BlockTransaction < ApplicationRecord
  belongs_to :ckb_transaction
  belongs_to :block
end

# == Schema Information
#
# Table name: block_transactions
#
#  id                 :bigint           not null, primary key
#  block_id           :bigint
#  ckb_transaction_id :bigint
#  tx_index           :integer          default(0), not null
#
# Indexes
#
#  block_tx_alt_pk                                 (block_id,ckb_transaction_id) UNIQUE
#  block_tx_index                                  (block_id,tx_index) UNIQUE
#  index_block_transactions_on_block_id            (block_id)
#  index_block_transactions_on_ckb_transaction_id  (ckb_transaction_id)
#

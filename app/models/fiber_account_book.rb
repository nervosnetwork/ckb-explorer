class FiberAccountBook < ApplicationRecord
  belongs_to :fiber_graph_channel, -> { with_deleted }
  belongs_to :address
  belongs_to :ckb_transaction
end

# == Schema Information
#
# Table name: fiber_account_books
#
#  id                     :bigint           not null, primary key
#  fiber_graph_channel_id :bigint
#  ckb_transaction_id     :bigint
#  address_id             :bigint
#
# Indexes
#
#  index_fiber_account_books_on_address_id_and_ckb_transaction_id  (address_id,ckb_transaction_id) UNIQUE
#  index_fiber_account_books_on_ckb_transaction_id                 (ckb_transaction_id)
#

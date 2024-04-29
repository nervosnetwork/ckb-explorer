class BitcoinTransfer < ApplicationRecord
  belongs_to :bitcoin_transaction
  belongs_to :ckb_transaction

  enum lock_type: { rgbpp: 0, btc_time: 1 }
end

# == Schema Information
#
# Table name: bitcoin_transfers
#
#  id                     :bigint           not null, primary key
#  bitcoin_transaction_id :bigint
#  ckb_transaction_id     :bigint
#  cell_output_id         :bigint
#  lock_type              :integer          default("rgbpp")
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_bitcoin_transfers_on_bitcoin_transaction_id  (bitcoin_transaction_id)
#  index_bitcoin_transfers_on_cell_output_id          (cell_output_id) UNIQUE
#  index_bitcoin_transfers_on_ckb_transaction_id      (ckb_transaction_id)
#

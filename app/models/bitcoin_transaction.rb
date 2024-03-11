class BitcoinTransaction < ApplicationRecord
  has_many :bitcoin_vouts

  def confirmations
    Rails.cache.fetch([self.class.name, "tip_block"], expires_in: 1.minute) do
      blocks = Bitcoin::Rpc.instance.getchaintips
      tip_block = blocks.find { |h| h["status"] == "active" }
      tip_block["height"] - block_height
    rescue StandardError => e
      Rails.logger.error "get tip block faild: #{e.message}"
      0
    end
  end

  def ckb_transaction_hash
    ckb_transaction = bitcoin_vouts&.take&.ckb_transaction
    return ckb_transaction.tx_hash if ckb_transaction
  end
end

# == Schema Information
#
# Table name: bitcoin_transactions
#
#  id           :bigint           not null, primary key
#  txid         :binary
#  hash         :binary
#  time         :bigint
#  block_hash   :binary
#  block_height :bigint
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_bitcoin_transactions_on_txid  (txid) UNIQUE
#

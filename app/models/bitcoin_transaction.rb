class BitcoinTransaction < ApplicationRecord
  has_many :bitcoin_vouts
  has_many :bitcoin_transfers

  def confirmations
    Rails.cache.fetch("#{txid}/confirmations", expires_in: 30.seconds) do
      rpc = Bitcoin::Rpc.instance
      raw_transaction = rpc.getrawtransaction(txid, 2)
      raw_transaction.dig("result", "confirmations")
    rescue StandardError => e
      Rails.logger.error "get #{txid} confirmations  failed: #{e.message}"
      0
    end
  end

  def ckb_transaction_hash
    ckb_transaction = bitcoin_transfers&.take&.ckb_transaction
    return ckb_transaction.tx_hash if ckb_transaction
  end
end

# == Schema Information
#
# Table name: bitcoin_transactions
#
#  id           :bigint           not null, primary key
#  txid         :binary
#  tx_hash      :binary
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

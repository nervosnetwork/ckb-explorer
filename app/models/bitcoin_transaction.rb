class BitcoinTransaction < ApplicationRecord
  has_many :bitcoin_vouts
  has_many :bitcoin_transfers

  def confirmations
    tip_block_height =
      Rails.cache.fetch("tip_block_height", expires_in: 5.minutes) do
        chain_info = Bitcoin::Rpc.instance.getblockchaininfo
        chain_info["headers"]
      rescue StandardError => e
        Rails.logger.error "get tip block faild: #{e.message}"
        nil
      end

    return 0 unless tip_block_height

    refresh_block_height! if block_hash.blank?
    block_height == 0 ? 0 : tip_block_height - block_height
  end

  def ckb_transaction_hash
    ckb_transaction = bitcoin_vouts&.take&.ckb_transaction
    return ckb_transaction.tx_hash if ckb_transaction
  end

  def refresh_block_height!
    rpc = Bitcoin::Rpc.instance
    raw_transaction = rpc.getrawtransaction(txid, 2)
    block_header = rpc.getblockheader(raw_transaction["blockhash"])
    update(block_hash: raw_transaction["blockhash"], block_height: block_header["height"])
  rescue StandardError => e
    Rails.logger.error "refresh block height error: #{e.message}"
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

module Api
  module V2
    class BitcoinVoutsController < BaseController
      def verify
        cell_output = CellOutput.find_by(
          tx_hash: params.dig("outpoint", "tx_hash"),
          cell_index: params.dig("outpoint", "index"),
        )
        head :not_found and return unless cell_output

        consumed_txid = params.dig("consumed_by", "txid")
        consumed_by = find_consumed_by_transaction(consumed_txid)

        # utxo may be bound by multiple cells
        previous_vout = params.dig("consumed_by", "vin")
        bitcoin_vouts = BitcoinVout.includes(:bitcoin_transaction).
          where(bitcoin_transactions: { txid: previous_vout["txid"] },
                bitcoin_vouts: { index: previous_vout["index"], op_return: false })
        bitcoin_vouts.each do |vout|
          next if vout.unbound? || vout.normal?

          status =
            if vout.cell_output.dead?
              "normal"
            elsif vout.cell_output == cell_output
              "binding"
            else
              "unbound"
            end
          vout.update(consumed_by:, status:)
        end

        head :no_content
      end

      private

      def find_consumed_by_transaction(txid)
        # check whether consumed_by has been synchronized
        consumed_by = BitcoinTransaction.find_by(txid:)
        unless consumed_by
          raw_tx = fetch_raw_transaction(txid)
          consumed_by = BitcoinTransaction.create!(
            txid: raw_tx["txid"],
            tx_hash: raw_tx["hash"],
            time: raw_tx["time"],
            block_hash: raw_tx["blockhash"],
            block_height: 0,
          )
        end
        consumed_by
      end

      def fetch_raw_transaction(txid)
        data = Rails.cache.read(txid)
        data ||= Bitcoin::Rpc.instance.getrawtransaction(txid, 2)
        Rails.cache.write(txid, data, expires_in: 10.minutes) unless Rails.cache.exist?(txid)
        data["result"]
      rescue StandardError => e
        Rails.logger.error "get bitcoin raw transaction #{txid} failed: #{e}"
        nil
      end
    end
  end
end

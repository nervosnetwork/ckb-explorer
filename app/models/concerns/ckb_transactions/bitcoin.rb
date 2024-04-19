# frozen_string_literal: true

module CkbTransactions
  module Bitcoin
    extend ActiveSupport::Concern
    included do
      has_many :bitcoin_vouts
      has_many :bitcoin_vins

      def rgb_transaction?
        !!tags&.include?("rgbpp")
      end

      def btc_time_transaction?
        is_btc_time_lock_cell = ->(lock_script) { CkbUtils.is_btc_time_lock_cell?(lock_script) }
        inputs.includes(:lock_script).any? { is_btc_time_lock_cell.call(_1.lock_script) } ||
          outputs.includes(:lock_script).any? { is_btc_time_lock_cell.call(_1.lock_script) }
      end

      def rgb_commitment
        return unless rgb_transaction?

        # In the outputs, there is exactly one OP_RETURN containing a commitment.
        op_return = bitcoin_vouts.find_by(op_return: true)
        op_return&.commitment
      end

      def rgb_txid
        return unless rgb_transaction?

        bitcoin_transaction&.txid
      end

      def leap_direction
        return unless rgb_transaction?

        return "in" if bitcoin_vins.count < bitcoin_vouts.without_op_return.count
        return "out" if bitcoin_vins.count > bitcoin_vouts.without_op_return.count

        nil
      end

      def rgb_cell_changes
        return 0 unless rgb_transaction?

        bitcoin_vouts.without_op_return.count - bitcoin_vins.count
      end

      def bitcoin_transaction
        BitcoinTransaction.includes(:bitcoin_vouts).
          find_by(bitcoin_vouts: { ckb_transaction_id: id })
      end
    end
  end
end

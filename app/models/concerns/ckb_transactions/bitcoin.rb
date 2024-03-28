# frozen_string_literal: true

module CkbTransactions
  module Bitcoin
    extend ActiveSupport::Concern
    included do
      has_many :bitcoin_vouts
      has_many :bitcoin_vins

      def rgb_transaction?
        bitcoin_vins.exists? || bitcoin_vouts.exists?
      end

      def rgb_commitment
        return unless rgb_transaction?

        # In the outputs, there is exactly one OP_RETURN containing a commitment.
        op_return = bitcoin_vouts.find_by(op_return: true)
        op_return&.commitment
      end

      def rgb_txid
        return unless rgb_transaction?

        bitcoin_transaction = BitcoinTransaction.includes(:bitcoin_vouts).find_by(bitcoin_vouts: { ckb_transaction_id: id })
        bitcoin_transaction&.txid
      end
    end
  end
end

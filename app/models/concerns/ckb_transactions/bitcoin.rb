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

      def commitment
        return unless rgb_transaction?

        # In the outputs, there is exactly one OP_RETURN containing a commitment.
        op_return_vout = bitcoin_vouts.find_by(op_return: true)
        op_return_vout.commitment
      end
    end
  end
end

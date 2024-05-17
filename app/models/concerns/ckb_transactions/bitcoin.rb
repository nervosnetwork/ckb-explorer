# frozen_string_literal: true

module CkbTransactions
  module Bitcoin
    extend ActiveSupport::Concern
    included do
      has_many :bitcoin_vouts
      has_many :bitcoin_vins
      has_many :bitcoin_transfers
      has_one :bitcoin_annotation

      delegate :leap_direction, to: :bitcoin_annotation, allow_nil: true
      delegate :transfer_step, to: :bitcoin_annotation, allow_nil: true

      def rgb_transaction?
        !!bitcoin_annotation&.tags&.include?("rgbpp")
      end

      def btc_time_transaction?
        !!bitcoin_annotation&.tags&.include?("btc_time")
      end

      def rgb_txid
        return if !rgb_transaction? && !btc_time_transaction?

        transfer = bitcoin_transfers.order(lock_type: :asc).first
        transfer&.bitcoin_transaction&.txid
      end

      def rgb_cell_changes
        return 0 unless rgb_transaction?

        bitcoin_vouts.without_op_return.count - bitcoin_vins.count
      end
    end
  end
end

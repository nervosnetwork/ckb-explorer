module Api
  module V2
    class TransactionsController < BaseController
      def raw
      end

      protected

      def find_transaction
        @transaction = CkbTransaction.find_by tx_hash: params[:id]
      end
    end
  end
end

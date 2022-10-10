module Api
  module V2
    class TransactionsController < BaseController
      before_action :find_transaction, only: [:raw]
      def raw
        if stale?(etag: @transaction.tx_hash, public: true)
          expires_in 1.day
          render json: @transaction.to_raw
        end
      end

      protected

      def find_transaction
        @transaction = CkbTransaction.find(params[:id]) || PoolTransactionEntry.find_by(tx_hash: params[:id])
      end
    end
  end
end

module Api
  module V2
    class TransactionsController < BaseController
      before_action :find_transaction, only: [:raw]
      def raw
        fresh_when etag: @transaction.tx_hash, public: true
        render json: @transaction.to_raw
      end

      protected

      def find_transaction
        @transaction = CkbTransaction.cached_find(params[:id]) || PoolTransactionEntry.find_by(tx_hash: params[:id])
      end
    end
  end
end

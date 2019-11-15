module Api
  module V1
    class DaoContractTransactionsController < ApplicationController
      before_action :validate_query_params, only: :show

      def show
        ckb_transaction = CkbTransaction.find_by(tx_hash: params[:id])

        raise Api::V1::Exceptions::CkbTransactionNotFoundError if ckb_transaction.blank? || !ckb_transaction.dao_transaction?

        render json: CkbTransactionSerializer.new(ckb_transaction)
      end

      private

      def validate_query_params
        validator = Validations::CkbTransaction.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status: status
        end
      end
    end
  end
end

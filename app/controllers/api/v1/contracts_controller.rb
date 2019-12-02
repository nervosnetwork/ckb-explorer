module Api
  module V1
    class ContractsController < ApplicationController
      def show
        raise Api::V1::Exceptions::ContractNotFoundError if params[:id] != DaoContract::CONTRACT_NAME

        render json: DaoContractSerializer.new(DaoContract.default_contract)
      end
    end
  end
end

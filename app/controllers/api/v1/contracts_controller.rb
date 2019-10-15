module Api
  module V1
    class ContractsController < ApplicationController
      def show
        raise Api::V1::Exceptions::ContractNotFoundError if params[:id] != "dao_contract"

        render json: DaoContractSerializer.new(DaoContract.default_contract)
      end
    end
  end
end


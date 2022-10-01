module Api
  module V1
    class ContractsController < ApplicationController
      def show
        raise Api::V1::Exceptions::ContractNotFoundError if params[:id] != DaoContract::CONTRACT_NAME

        dao_contract = DaoContract.default_contract
        json = DaoContractSerializer.new(dao_contract).serialized_json

        render json: json
      end
    end
  end
end

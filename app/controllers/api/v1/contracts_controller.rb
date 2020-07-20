module Api
  module V1
    class ContractsController < ApplicationController
      def show
        raise Api::V1::Exceptions::ContractNotFoundError if params[:id] != DaoContract::CONTRACT_NAME

        dao_contract = DaoContract.where(id: 1)
        json =
          Rails.cache.realize(dao_contract.cache_key, version: dao_contract.cache_version, race_condition_ttl: 3.seconds) do
            DaoContractSerializer.new(dao_contract.first).serialized_json
          end

        render json: json
      end
    end
  end
end

module Api
  module V1
    class DaoDepositorsController < ApplicationController
      def index
        addresses = Address.where("dao_deposit > 0").order(dao_deposit: :desc).limit(100)

        render json: DaoDepositorSerializer.new(addresses)
      end
    end
  end
end

module Api
  module V1
    class DaoDepositorsController < ApplicationController
      def index
        addresses = Address.select(:id, :address_hash, :dao_deposit, :average_deposit_time).where(is_depositor: true).where("dao_deposit > 0").order(dao_deposit: :desc).limit(100)

        render json: DaoDepositorSerializer.new(addresses)
      end
    end
  end
end

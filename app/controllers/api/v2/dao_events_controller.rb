module Api::V2
  class DaoEventsController < BaseController

    def index
      address = Address.find_by(lock_hash: address_to_lock_hash(params[:address]))

      ckb_transactions = address.ckb_dao_transactions

      page = params[:page] || 1
      page_size = params[:page_size] || 10

      total = ckb_transactions.count
      ckb_transactions = ckb_transactions.page(page).per(page_size)

      activities = CkbTransactionsSerializer.new(ckb_transactions).serializable_hash

      render json: {
        data: {
          id: address.id,
          address: address.address_hash.to_s,
          deposit_capacity: address.dao_deposit.to_s,
          average_deposit_time: address.average_deposit_time.to_s,
          activities: activities[:data].map { |data|
            result = data[:attributes]
            result.delete(:is_cellbase)
            result.delete(:income)
            result
          }
        },
        meta: {
          total: total,
          page_size: page_size
        }
      }
    end
  end
end

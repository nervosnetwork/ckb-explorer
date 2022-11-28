module Api::V2
  class DaoEventsController < BaseController
    def index
      address = Address.find_by(lock_hash: address_to_lock_hash(params[:address]))

      dao_events = DaoEvent
        .includes(:ckb_transaction)
        .where(address_id: address.id)
        .where(event_type: [:deposit_to_dao, :withdraw_from_dao, :issue_interest])

      page = params[:page] || 1
      page_size = params[:page_size] || 10

      total = dao_events.count
      dao_events = dao_events.page(page).per(page_size)

      render json: {
        data: {
          id: address.id,
          address: address.address_hash.to_s,
          deposit_capacity: address.dao_deposit.to_s,
          average_deposit_time: address.average_deposit_time.to_s,
          activities: dao_events.map {|dao_event|
            ckb_transaction = dao_event.ckb_transaction

            {
              tx_hash: ckb_transaction.tx_hash.to_s,
              from: dao_event.get_froms,
              to: address.address_hash.to_s,
              block_number: ckb_transaction.block_number.to_s,
              timestamp: dao_event.block_timestamp.to_s,
              type: dao_event.event_type.to_s,
              amount: dao_event.value.to_s
            }
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

module Api::V2
  class DaoEventsController < BaseController
    def index
      address = Address.find_by(lock_hash: address_to_lock_hash(params[:address]))
      Rails.logger.info "== address: #{address.inspect}"

      dao_events = DaoEvent
        .includes(:ckb_transaction)
        .where(address_id: address.id)
        .where(event_type: [:deposit_to_dao, :withdraw_from_dao, :issue_interest])


      page = params[:page] || 1
      page_size = params[:page_size] || 10

      total = dao_events.count
      dao_events = dao_events.page(page).per(page_size)
      Rails.logger.info "== dao_events: #{dao_events.inspect}"

      render json: {
        data: {
          id: address.id,
          address: address.address_hash.to_s,
          deposit_capacity: address.dao_deposit.to_s,
          average_deposit_time: address.average_deposit_time.to_s,
          activities: dao_events.map {|dao_event|
            ckb_transaction = dao_event.ckb_transaction

            type = ''
            amount = ''

            if dao_event.event_type == 'issue_interest'
              # conver this event_type name to "nervos_dao_withdrawing" for frontend
              type = 'nervos_dao_withdrawing'
              display_input = ckb_transaction.display_inputs.select { |display_input|
                display_input[:address_hash] == dao_event.address.address_hash
              }[0]
              amount = display_input[:capacity].to_i + display_input[:interest].to_i
            else
              type = dao_event.event_type.to_s
              amount = dao_event.value
            end

            {
              tx_hash: ckb_transaction.tx_hash.to_s,
              from: dao_event.get_froms,
              to: address.address_hash.to_s,
              block_number: ckb_transaction.block_number.to_s,
              timestamp: dao_event.block_timestamp.to_s,
              type: type,
              amount: amount.to_s
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

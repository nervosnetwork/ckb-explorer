module Api::V2
  class DaoEventsController < BaseController
    def index
      address = Address.find_by(address_hash: params[:address])

      page = params[:page] || 1
      page_size = params[:page_size] || 10

      dao_events = DaoEvent
        .includes(:ckb_transaction)
        .where(address_id: address.id)
        .where(event_type: [:deposit_to_dao, :withdraw_from_dao])
        .page(page)
        .per(page_size)

      options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: dao_events, page: page, page_size: page_size).call
      render json: AddressWithDaoEventsSerializer.new(address, options.merge(params: {dao_events: dao_events}))
    end
  end
end

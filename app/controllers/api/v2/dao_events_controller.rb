module Api::V2
  class DaoEventsController < BaseController
    def index
      address = Address.find_by(address_hash: params[:address])

      dao_events = DaoEvent.includes(:ckb_transaction).where(address_id: address.id)
      render json: AddressWithDaoEventsSerializer.new(address, params: {dao_events: dao_events})
    end
  end
end

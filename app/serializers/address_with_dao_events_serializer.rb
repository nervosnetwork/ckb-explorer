class AddressWithDaoEventsSerializer
  include FastJsonapi::ObjectSerializer

  attribute :address do |object|
    object.address_hash.to_s
  end

  attribute :deposit_capacity do |object|
    object.dao_deposit.to_s
  end

  attribute :average_deposit_time do |object|
    object.average_deposit_time.to_s
  end

  attribute :activities do |object, params|
    dao_events = params[:dao_events]

    dao_events.map {|dao_event|
      ckb_transaction = dao_event.ckb_transaction
      {
        tx_hash: ckb_transaction.tx_hash.to_s,
        from: '-',
        to: dao_event.address.address_hash.to_s,
        block_number: ckb_transaction.block_number.to_s,
        timestamp: dao_event.block_timestamp.to_s,
        type: dao_event.event_type.to_s,
        amount: dao_event.value.to_s
      }
    }
  end
end

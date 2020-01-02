class CkbTransactionListSerializer
  include FastJsonapi::ObjectSerializer

  attribute :transaction_hash, &:tx_hash

  attribute :block_number do |object|
    object.block_number.to_s
  end
  attribute :block_timestamp do |object|
    object.block_timestamp.to_s
  end
  attribute :capacity_involved do |object|
    object.capacity_involved.to_s
  end
  attribute :live_cell_changes do |object|
    object.live_cell_changes.to_s
  end
end

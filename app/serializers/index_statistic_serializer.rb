class IndexStatisticSerializer
  include FastJsonapi::ObjectSerializer
  cache_options enabled: true, cache_length: 15.seconds

  attributes :epoch_info

  attribute :tip_block_number do |object|
    object.tip_block_number&.to_s
  end
  attribute :average_block_time do |object|
    object.average_block_time&.to_s
  end
  attribute :current_epoch_difficulty do |object|
    object.current_epoch_difficulty&.to_s
  end
  attribute :hash_rate do |object|
    object.hash_rate&.to_s
  end
  attribute :estimated_epoch_time do |object|
    object.estimated_epoch_time&.to_s
  end
  attribute :transactions_last_24hrs do |object|
    object.transactions_last_24hrs.to_s
  end
  attribute :transactions_count_per_minute do |object|
    object.transactions_count_per_minute.to_s
  end
  attribute :reorg_started_at do |_o|
    CkbSync::NewNodeDataProcessor.reorg_started_at.value
  end
end

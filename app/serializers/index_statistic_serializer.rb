class IndexStatisticSerializer
  include FastJsonapi::ObjectSerializer
  cache_options enabled: true, cache_length: 15.seconds

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
end

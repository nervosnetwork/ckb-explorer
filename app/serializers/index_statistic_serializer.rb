class IndexStatisticSerializer
  include FastJsonapi::ObjectSerializer
  cache_options enabled: true, cache_length: 15.seconds

  attributes :tip_block_number, :average_block_time, :current_epoch_difficulty, :hash_rate
end

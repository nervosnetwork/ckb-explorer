class IndexStatisticSerializer
  include FastJsonapi::ObjectSerializer
  cache_options enabled: true, cache_length: 15.seconds

  attributes :tip_block_number, :current_epoch_average_block_time, :current_epoch_difficulty, :hash_rate
end

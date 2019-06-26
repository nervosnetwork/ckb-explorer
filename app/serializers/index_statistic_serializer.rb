class IndexStatisticSerializer
  include FastJsonapi::ObjectSerializer

  attributes :tip_block_number, :average_block_time, :current_epoch_difficulty, :hash_rate
end

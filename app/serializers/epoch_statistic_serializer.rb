class EpochStatisticSerializer
  include FastJsonapi::ObjectSerializer

  attribute :epoch_number do |object|
    object.epoch_number.to_s
  end

  attribute :difficulty, if: Proc.new { |_record, params|
    params && params[:indicator].include?("difficulty")
  }

  attribute :uncle_rate, if: Proc.new { |_record, params|
    params && params[:indicator].include?("uncle_rate")
  } do |object|
    object.uncle_rate.to_d.truncate(5).to_s
  end

  attribute :hash_rate, if: Proc.new { |_record, params|
    params && params[:indicator].include?("hash_rate")
  }

  attribute :epoch_time, if: Proc.new { |_record, params|
    params && params[:indicator].include?("epoch_time")
  } do |object|
    object.epoch_time.to_s
  end

  attribute :epoch_length, if: Proc.new { |_record, params|
    params && params[:indicator].include?("epoch_length")
  } do |object|
    object.epoch_length.to_s
  end

  attribute :largest_block do |object|
    {
      number: object.largest_block_number,
      size: object.largest_block_size
    }
  end

  attribute :largest_tx do |object|
    {
      tx_hash: object.largest_tx_hash,
      bytes: object.largest_tx_bytes
    }
  end
end

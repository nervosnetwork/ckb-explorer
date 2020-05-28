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
end

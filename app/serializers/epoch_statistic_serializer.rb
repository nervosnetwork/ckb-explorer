class EpochStatisticSerializer
  include FastJsonapi::ObjectSerializer

  attributes :epoch_number

  attribute :difficulty, if: Proc.new {|_record, params|
    params && params[:indicator].include?("difficulty")
  }

  attribute :uncle_rate, if: Proc.new {|_record, params|
    params && params[:indicator].include?("uncle_rate")
  }
end

class DailyStatisticSerializer
  include FastJsonapi::ObjectSerializer

  attribute :created_at_unixtimestamp do |object|
    object.created_at_unixtimestamp.to_s
  end

  attribute :transactions_count, if: Proc.new {|_record, params|
    params && params[:indicator] == "transactions_count"
  }

  attribute :addresses_count, if: Proc.new {|_record, params|
    params && params[:indicator] == "addresses_count"
  }

  attribute :total_dao_deposit, if: Proc.new {|_record, params|
    params && params[:indicator] == "total_dao_deposit"
  }
end

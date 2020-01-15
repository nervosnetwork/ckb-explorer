class DailyStatisticSerializer
  include FastJsonapi::ObjectSerializer

  attribute :created_at_unixtimestamp do |object|
    object.created_at_unixtimestamp.to_s
  end

  attribute :transactions_count, if: Proc.new { |_record, params|
    params && params[:indicator] == "transactions_count"
  }

  attribute :addresses_count, if: Proc.new { |_record, params|
    params && params[:indicator] == "addresses_count"
  }

  attribute :total_dao_deposit, if: Proc.new { |_record, params|
    params && params[:indicator] == "total_dao_deposit"
  }

  attribute :live_cells_count, if: Proc.new { |_record, params|
    params && params[:indicator] == "live_cells_count"
  }

  attribute :dead_cells_count, if: Proc.new { |_record, params|
    params && params[:indicator] == "dead_cells_count"
  }

  attribute :avg_hash_rate, if: Proc.new { |_record, params|
    params && params[:indicator] == "avg_hash_rate"
  }

  attribute :avg_difficulty, if: Proc.new { |_record, params|
    params && params[:indicator] == "avg_difficulty"
  }

  attribute :uncle_rate, if: Proc.new { |_record, params|
    params && params[:indicator] == "uncle_rate"
  }
end

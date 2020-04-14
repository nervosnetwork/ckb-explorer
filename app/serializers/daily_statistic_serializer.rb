class DailyStatisticSerializer
  include FastJsonapi::ObjectSerializer

  attribute :created_at_unixtimestamp do |object|
    object.created_at_unixtimestamp.to_s
  end

  attribute :transactions_count, if: Proc.new { |_record, params|
    params && params[:indicator].include?("transactions_count")
  }

  attribute :addresses_count, if: Proc.new { |_record, params|
    params && params[:indicator].include?("addresses_count")
  }

  attribute :total_dao_deposit, if: Proc.new { |_record, params|
    params && params[:indicator].include?("total_dao_deposit")
  }

  attribute :live_cells_count, if: Proc.new { |_record, params|
    params && params[:indicator].include?("live_cells_count")
  }

  attribute :dead_cells_count, if: Proc.new { |_record, params|
    params && params[:indicator].include?("dead_cells_count")
  }

  attribute :avg_hash_rate, if: Proc.new { |_record, params|
    params && params[:indicator].include?("avg_hash_rate")
  }

  attribute :avg_difficulty, if: Proc.new { |_record, params|
    params && params[:indicator].include?("avg_difficulty")
  }

  attribute :uncle_rate, if: Proc.new { |_record, params|
    params && params[:indicator].include?("uncle_rate")
  }

  attribute :total_depositors_count, if: Proc.new { |_record, params|
    params && params[:indicator].include?("total_depositors_count")
  }

  attribute :address_balance_distribution, if: Proc.new { |_record, params|
    params && params[:indicator].include?("address_balance_distribution")
  }
end

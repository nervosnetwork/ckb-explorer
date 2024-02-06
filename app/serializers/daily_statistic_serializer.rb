class DailyStatisticSerializer
  include FastJsonapi::ObjectSerializer

  attribute :created_at_unixtimestamp do |object|
    object.created_at_unixtimestamp.to_s
  end

  attribute :transactions_count, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("transactions_count")
  }

  attribute :addresses_count, if: Proc.new { |_record, params|
    params.present?  && params[:indicator].include?("addresses_count")
  }

  attribute :total_dao_deposit, if: Proc.new { |_record, params|
    params.present?  && params[:indicator].include?("total_dao_deposit")
  }

  attribute :live_cells_count, if: Proc.new { |_record, params|
    params.present?  && params[:indicator].include?("live_cells_count")
  }

  attribute :dead_cells_count, if: Proc.new { |_record, params|
    params.present?  && params[:indicator].include?("dead_cells_count")
  }

  attribute :avg_hash_rate, if: Proc.new { |_record, params|
    params.present?  && params[:indicator].include?("avg_hash_rate")
  } do |object|
    object.avg_hash_rate.to_d.truncate(6).to_s
  end

  attribute :avg_difficulty, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("avg_difficulty")
  } do |object|
    object.avg_difficulty.to_d.truncate(3).to_s
  end

  attribute :uncle_rate, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("uncle_rate")
  }

  attribute :total_depositors_count, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("total_depositors_count")
  }

  attribute :address_balance_distribution, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("address_balance_distribution")
  }

  attribute :total_tx_fee, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("total_tx_fee")
  } do |object|
    object.total_tx_fee.to_s
  end

  attribute :occupied_capacity, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("occupied_capacity")
  } do |object|
    object.occupied_capacity.to_s
  end

  attribute :daily_dao_deposit, if: Proc.new { |_record, params|
    params.present? && params[:indicator].split("-").any? { |item| item == "daily_dao_deposit" }
  } do |object|
    object.daily_dao_deposit.to_s
  end

  attribute :daily_dao_depositors_count, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("daily_dao_depositors_count")
  } do |object|
    object.daily_dao_depositors_count.to_s
  end

  attribute :daily_dao_withdraw, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("daily_dao_withdraw")
  } do |object|
    object.daily_dao_withdraw.to_s
  end

  attribute :circulation_ratio, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("circulation_ratio")
  } do |object|
    object.circulation_ratio.truncate(4).to_s
  end

  attribute :nodes_count, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("nodes_count")
  } do |object|
    object.nodes_count.to_s
  end

  attribute :circulating_supply, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("circulating_supply")
  }

  attribute :burnt, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("burnt")
  } do |object|
    object.burnt.to_s
  end

  attribute :locked_capacity, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("locked_capacity")
  } do |object|
    object.locked_capacity.to_s
  end

  attribute :treasury_amount, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("treasury_amount")
  }

  attribute :mining_reward, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("mining_reward")
  }

  attribute :deposit_compensation, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("deposit_compensation")
  }

  attribute :liquidity, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("liquidity")
  } do |object|
    object.liquidity.to_s
  end

  attribute :ckb_hodl_wave, if: Proc.new { |_record, params|
    params.present? && params[:indicator].include?("ckb_hodl_wave")
  }
end

class StatisticSerializer
  include FastJsonapi::ObjectSerializer

  attribute :tip_block_number, if: Proc.new { |_record, params|
    params && params[:info_name] == "tip_block_number"
  }

  attribute :average_block_time, if: Proc.new { |_record, params|
    params && params[:info_name] == "average_block_time"
  }

  attribute :current_epoch_difficulty, if: Proc.new { |_record, params|
    params && params[:info_name] == "current_epoch_difficulty"
  }

  attribute :hash_rate, if: Proc.new { |_record, params|
    params && params[:info_name] == "hash_rate"
  }

  attribute :miner_ranking, if: Proc.new { |_record, params|
    ENV["MINER_RANKING_EVENT"] && params && params[:info_name] == "miner_ranking"
  }

  attribute :blockchain_info, if: Proc.new { |_record, params|
    params && params[:info_name] == "blockchain_info"
  } do |object|
    JSON.parse(object.blockchain_info)
  end

  attribute :flush_cache_info, if: Proc.new { |_record, params|
    params && params[:info_name] == "flush_cache_info"
  }

  attribute :address_balance_ranking, if: Proc.new { |_record, params|
    params && params[:info_name] == "address_balance_ranking"
  }

  attribute :maintenance_info, if: Proc.new { |_record, params|
    params && params[:info_name] == "maintenance_info"
  }

  attribute :ckb_hodl_waves, if: Proc.new { |_record, params|
    params && params[:info_name] == "ckb_hodl_waves"
  }
end

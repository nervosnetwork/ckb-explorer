class BlockStatisticSerializer
  include FastJsonapi::ObjectSerializer

  attribute :block_number do |object|
    object.block_number.to_s
  end

  attribute :difficulty, if: Proc.new {|_record, params|
    params && params[:indicator].include?("difficulty")
  }

  attribute :hash_rate, if: Proc.new {|_record, params|
    params && params[:indicator].include?("hash_rate")
  }

  attribute :live_cells_count, if: Proc.new {|_record, params|
    params && params[:indicator].include?("live_cells_count")
  }

  attribute :dead_cells_count, if: Proc.new {|_record, params|
    params && params[:indicator].include?("dead_cells_count")
  }
end

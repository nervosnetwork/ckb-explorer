class BlockStatisticSerializer
  include FastJsonapi::ObjectSerializer

  attributes :block_number

  attribute :difficulty, if: Proc.new {|_record, params|
    params && params[:indicator].include?("difficulty")
  }

  attribute :hash_rate, if: Proc.new {|_record, params|
    params && params[:indicator].include?("hash_rate")
  }

  attribute :live_cell_count, if: Proc.new {|_record, params|
    params && params[:indicator].include?("live_cell_count")
  }

  attribute :dead_cell_count, if: Proc.new {|_record, params|
    params && params[:indicator].include?("dead_cell_count")
  }
end

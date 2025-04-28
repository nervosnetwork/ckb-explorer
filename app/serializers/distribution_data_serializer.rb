class DistributionDataSerializer
  include FastJsonapi::ObjectSerializer

  attribute :address_balance_distribution, if: Proc.new { |_record, params|
    params && params[:indicator].include?("address_balance_distribution")
  } do |object|
    object.address_balance_distribution.map { |distribution| distribution.map(&:to_s) }
  end

  attribute :block_time_distribution, if: Proc.new { |_record, params|
    params && params[:indicator].include?("block_time_distribution")
  } do |object|
    object.block_time_distribution.map { |distribution| distribution.map(&:to_s) }
  end

  attribute :epoch_time_distribution, if: Proc.new { |_record, params|
    params && params[:indicator].include?("epoch_time_distribution")
  } do |object|
    object.epoch_time_distribution.map { |distribution| distribution.map(&:to_s) }
  end

  attribute :epoch_length_distribution, if: Proc.new { |_record, params|
    params && params[:indicator].include?("epoch_length_distribution")
  } do |object|
    object.epoch_length_distribution.map { |distribution| distribution.map(&:to_s) }
  end

  attribute :average_block_time, if: Proc.new { |_record, params|
    params && params[:indicator].include?("average_block_time")
  } do |object|
    object.average_block_time
  end

  attribute :nodes_distribution, if: Proc.new { |_record, params|
    params && params[:indicator].include?("nodes_distribution")
  } do |object|
    object.nodes_distribution
  end

  attribute :block_propagation_delay_history, if: Proc.new { |_record, params|
    params && params[:indicator].include?("block_propagation_delay_history")
  } do |object|
    object.block_propagation_delay_history
  end

  attribute :transaction_propagation_delay_history, if: Proc.new { |_record, params|
    params && params[:indicator].include?("transaction_propagation_delay_history")
  } do |object|
    object.transaction_propagation_delay_history
  end

  attribute :miner_address_distribution, if: Proc.new { |_record, params|
    params && params[:indicator].include?("miner_address_distribution")
  } do |object, params|
    if rs = params[:indicator].match(/(\d+)/)
      object.miner_address_distribution(rs[1].to_i)
    else
      object.miner_address_distribution
    end
  end

  attribute :created_at_unixtimestamp do |object|
    object.created_at_unixtimestamp.to_s
  end
end

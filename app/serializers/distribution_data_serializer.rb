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
end

class DistributionDataSerializer
  include FastJsonapi::ObjectSerializer

  attribute :address_balance_distribution do |object|
    object.address_balance_distribution.map { |distribution| distribution.map(&:to_s) }
  end
end

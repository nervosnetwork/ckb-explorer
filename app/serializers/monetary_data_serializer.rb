class MonetaryDataSerializer
  include FastJsonapi::ObjectSerializer

  attribute :nominal_apc, if: Proc.new { |_record, params|
    params && params[:indicator].include?("nominal_apc")
  } do |object|
    object.nominal_apc.map(&:to_s)
  end

  attribute :inflation_rate, if: Proc.new { |_record, params|
    params && params[:indicator].include?("inflation_rate")
  } do |object|
    {
      nominal_apc: object.nominal_apc(50).map(&:to_s),
      nominal_inflation_rate: object.nominal_inflation_rate.map(&:to_s),
      real_inflation_rate: object.real_inflation_rate.map(&:to_s)
    }
  end
end

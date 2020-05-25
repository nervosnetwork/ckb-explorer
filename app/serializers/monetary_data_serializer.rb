class MonetaryDataSerializer
  include FastJsonapi::ObjectSerializer

  attribute :nominal_apc, if: Proc.new { |_record, params|
    params && params[:indicator].include?("nominal_apc")
  } do |object|
    object.nominal_apc
  end

  attribute :inflation_rate, if: Proc.new { |_record, params|
    params && params[:indicator].include?("inflation_rate")
  } do |object|
    {
      nominal_apc: object.nominal_apc(50),
      nominal_inflation_rate: object.nominal_inflation_rate,
      real_inflation_rate: object.real_inflation_rate
    }
  end
end

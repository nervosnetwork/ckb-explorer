class MonetaryDataSerializer
  include FastJsonapi::ObjectSerializer

  attribute :nominal_apc, if: Proc.new { |_record, params|
    params && params[:indicator].include?("nominal_apc")
  } do |object, params|
    if rs = params[:indicator].match(/(\d+)/)
      object.nominal_apc(rs[1].to_i).map(&:to_s)
    else
      object.nominal_apc.map(&:to_s)
    end
  end

  attribute :nominal_inflation_rate, if: Proc.new { |_record, params|
    params && params[:indicator].include?("nominal_inflation_rate")
  } do |object|
    object.nominal_inflation_rate.map(&:to_s)
  end

  attribute :real_inflation_rate, if: Proc.new { |_record, params|
    params && params[:indicator].include?("real_inflation_rate")
  } do |object|
    object.real_inflation_rate.map(&:to_s)
  end
end

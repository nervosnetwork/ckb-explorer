class Shannon
  def initialize(n = nil, decimal_number = 8)
    n = 0 if n.blank?
    @value = n
    @decimal_number = decimal_number
  end

  def to_i
    return 0 if value.nil?
    value
  end

  def to_ckb
    number = BigDecimal.new(value.to_s)
    number = (number / 10 ** 8)
    number.round(decimal_number, :down)
  end

  private

  attr_reader :value, :decimal_number
end

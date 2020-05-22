class MonetaryData
  VALID_INDICATORS = %w(nominal_apc).freeze
  INITIAL_SUPPLY = 33.6
  SECONDARY_SUPPLY_PER_YEAR = 1.344

  def id
    Time.current.to_i
  end

  def nominal_apc
    initial_supply = 33.6
    secondary_supply_per_year = 1.344
    total_supplies_per_year.each_with_index.map do |_, index|
      cumulative_total_supply = index.zero? ? 0 : (0..index).reduce(0) { |memo, value| memo + total_supplies_per_year[value] }
      total_supply_so_far = initial_supply + cumulative_total_supply
      (secondary_supply_per_year / total_supply_so_far * 100).truncate(2)
    end
  end

  private

  def total_supplies_per_year
    @total_supplies_per_year ||=
      begin
        max_year = 20
        secondary_supply_per_month = SECONDARY_SUPPLY_PER_YEAR / 12
        total_supplies_per_year =
          (0...max_year).map do |year|
            primary_supply_per_year = 4.2/(2**(year / 4))
            primary_supply_per_month = primary_supply_per_year / 12
            [primary_supply_per_month + secondary_supply_per_month] * 12
          end

        total_supplies_per_year.flatten
      end
  end
end

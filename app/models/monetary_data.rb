class MonetaryData
  VALID_INDICATORS = %w(nominal_apc).freeze
  INITIAL_SUPPLY = 33.6
  SECONDARY_SUPPLY_PER_YEAR = 1.344

  def id
    Time.current.to_i
  end

  def nominal_apc
    total_supplies_per_year.each_with_index.map do |_, index|
      cumulative_total_supply = index.zero? ? 0 : (0..index).reduce(0) { |memo, value| memo + total_supplies_per_year[value] }
      total_supply_so_far = INITIAL_SUPPLY + cumulative_total_supply
      (SECONDARY_SUPPLY_PER_YEAR / total_supply_so_far * 100).truncate(4)
    end
  end

  def inflation_rate
    secondary_issuance_monthly = SECONDARY_SUPPLY_PER_YEAR / 12
    rs =
      total_supplies_per_year(50).each_with_index.map do |_, index|
        cumulative_total_supply = index.zero? ? 0 : (0..index).reduce(0) { |memo, value| memo + total_supplies_per_year[value] }
        INITIAL_SUPPLY + cumulative_total_supply
      end
    primary_supplies_per_year.map { |item| item + secondary_issuance_monthly }.zip(rs).map { |item| item.reduce(:/) * 12 }
  end

  private

  def total_supplies_per_year(max_year = 20)
    @total_supplies_per_year ||=
      begin
        secondary_supply_per_month = SECONDARY_SUPPLY_PER_YEAR / 12
        total_supplies_per_year =
          (0...max_year).each_with_index.map do |year, index|
            primary_supply_per_year = 4.2 / (2**(year / 4))
            primary_supply_per_month = primary_supply_per_year / 12
            if index.zero?
              [0] + [primary_supply_per_month + secondary_supply_per_month] * 11
            else
              [primary_supply_per_month + secondary_supply_per_month] * 12
            end
          end

        total_supplies_per_year.flatten
      end
  end

  def primary_supplies_per_year
    @primary_supplies_per_year ||=
      begin
        max_year = 50
        primary_supplies_per_year =
          (0...max_year).map do |year|
            primary_supply_per_year = 4.2 / (2**(year / 4))
            [primary_supply_per_year / 12] * 12
          end

        primary_supplies_per_year.flatten
      end
  end
end

class MonetaryData
  VALID_INDICATORS = %w(nominal_apc nominal_inflation_rate real_inflation_rate).freeze
  INITIAL_SUPPLY = 33.6
  SECONDARY_SUPPLY_PER_YEAR = 1.344

  def initialize
    @total_supplies_per_year = {}
  end

  def id
    Time.current.to_i
  end

  def nominal_apc(max_year = 20)
    Rails.cache.realize("nominal_apc#{max_year}") do
      total_supplies_per_year(max_year).each_with_index.map do |_, index|
        cumulative_total_supply =
          if index.zero?
            0
          else
            (0..index).reduce(0) do |memo, value|
              memo + total_supplies_per_year(max_year)[value]
            end
          end
        total_supply_so_far = INITIAL_SUPPLY + cumulative_total_supply
        (SECONDARY_SUPPLY_PER_YEAR / total_supply_so_far * 100).truncate(8)
      end
    end
  end

  def nominal_inflation_rate(max_year = 50)
    Rails.cache.realize("nominal_inflation_rate#{max_year}") do
      secondary_issuance_monthly = SECONDARY_SUPPLY_PER_YEAR / 12
      rs =
        total_supplies_per_year(max_year).each_with_index.map do |_, index|
          cumulative_total_supply =
            if index.zero?
              0
            else
              (0..index).reduce(0) do |memo, value|
                memo + total_supplies_per_year(max_year)[value]
              end
            end
          INITIAL_SUPPLY + cumulative_total_supply
        end
      primary_supplies_per_year.
        map { |item| item + secondary_issuance_monthly }.
        zip(rs).
        map { |item| (item.reduce(:/) * 12 * 100).truncate(8) }
    end
  end

  def real_inflation_rate(max_year = 50)
    Rails.cache.realize("real_inflation#{max_year}") do
      nominal_inflation_rate(max_year).
        zip(nominal_apc(max_year)).
        map { |item| item.reduce(:-).truncate(8) }
    end
  end

  private

  def total_supplies_per_year(max_year)
    @total_supplies_per_year[max_year] ||=
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

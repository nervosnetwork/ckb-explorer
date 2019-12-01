class MarketData
  VALID_INDICATORS = %w(total_supply circulating_supply)
  INITIAL_SUPPLY = BigDecimal(336 * 10**16)
  BURN_QUOTA = BigDecimal(84 * 10**16)
  ECOSYSTEM_QUOTA = INITIAL_SUPPLY * 0.17
  TEAM_QUOTA = INITIAL_SUPPLY * 0.15
  PRIVATE_SALE_QUOTA = INITIAL_SUPPLY * 0.14
  FOUNDING_PARTNER_QUOTA = INITIAL_SUPPLY * 0.05
  FOUNDATION_RESERVE_QUOTA = INITIAL_SUPPLY * 0.02

  attr_reader :indicator, :current_time

  def initialize(indicator = nil)
    @indicator = indicator
    @current_time = Time.find_zone("UTC").now
  end

  def call
    return unless indicator.in?(VALID_INDICATORS)

    send(indicator)
  end

  private

  def parsed_dao
    @parsed_dao ||= begin
      latest_dao = Block.recent.pick(:dao)
      CkbUtils.parse_dao(latest_dao)
    end
  end

  def total_supply
    result = parsed_dao.c_i - BURN_QUOTA

    (result / 10**8).truncate(8)
  end

  def circulating_supply
    result = parsed_dao.c_i - parsed_dao.s_i - BURN_QUOTA - ecosystem_locked - team_locked - private_sale_locked - founding_partners_locked - foundation_reserve_locked

    (result / 10**8).truncate(8)
  end

  def ecosystem_locked
    first_released_time = Time.find_zone("UTC").parse("2020-07-01")
    second_released_time = Time.find_zone("UTC").parse("2020-12-31")
    third_released_time = Time.find_zone("UTC").parse("2022-12-31")

    if current_time < first_released_time
      ECOSYSTEM_QUOTA * 0.97
    elsif current_time >= first_released_time && current_time < second_released_time
      ECOSYSTEM_QUOTA * 0.75
    elsif current_time >= second_released_time && current_time < third_released_time
      ECOSYSTEM_QUOTA * 0.5
    else
      0
    end
  end

  def team_locked
    first_released_time = Time.find_zone("UTC").parse("2020-05-01")
    second_released_time = Time.find_zone("UTC").parse("2021-05-01")
    third_released_time = Time.find_zone("UTC").parse("2022-05-01")

    if current_time < first_released_time
      TEAM_QUOTA * (2 / 3.to_d)
    elsif current_time >= first_released_time && current_time < second_released_time
      TEAM_QUOTA * 0.5
    elsif current_time >= second_released_time && current_time < third_released_time
      TEAM_QUOTA * (1 / 3.to_d)
    else
      0
    end
  end

  def private_sale_locked
    released_time = Time.zone.parse("2020-05-01")

    current_time < released_time ? PRIVATE_SALE_QUOTA * (1 / 3.to_d) : 0
  end

  def founding_partners_locked
    first_released_time = Time.find_zone("UTC").parse("2020-05-01")
    second_released_time = Time.find_zone("UTC").parse("2021-05-01")
    third_released_time = Time.find_zone("UTC").parse("2022-05-01")
    if current_time < first_released_time
      FOUNDING_PARTNER_QUOTA
    elsif current_time >= first_released_time && current_time < second_released_time
      FOUNDING_PARTNER_QUOTA * 0.75
    elsif current_time >= second_released_time && current_time < third_released_time
      FOUNDING_PARTNER_QUOTA * 0.5
    else
      0
    end
  end

  def foundation_reserve_locked
    released_time = Time.zone.parse("2020-07-01")

    current_time < released_time ? FOUNDATION_RESERVE_QUOTA : 0
  end
end

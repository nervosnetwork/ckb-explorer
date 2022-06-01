class MarketData
  VALID_INDICATORS = %w(total_supply circulating_supply).freeze
  INITIAL_SUPPLY = BigDecimal(336 * 10**16)
  BURN_QUOTA = BigDecimal(84 * 10**16)
  ECOSYSTEM_QUOTA = INITIAL_SUPPLY * 0.17
  TEAM_QUOTA = INITIAL_SUPPLY * 0.15
  PRIVATE_SALE_QUOTA = INITIAL_SUPPLY * 0.14
  FOUNDING_PARTNER_QUOTA = INITIAL_SUPPLY * 0.05
  FOUNDATION_RESERVE_QUOTA = INITIAL_SUPPLY * 0.02

  attr_reader :indicator, :current_timestamp, :tip_block_number, :unit

  def initialize(indicator: nil, tip_block_number: nil, unit: "ckb")
    @indicator = indicator
    @tip_block_number = tip_block_number
    @unit = unit
    @current_timestamp = tip_block_number.blank? ? CkbUtils.time_in_milliseconds(Time.find_zone("UTC").now) : tip_block.timestamp
  end

  def call
    return unless indicator.in?(VALID_INDICATORS)

    send(indicator)
  end

  def ecosystem_locked
    if current_timestamp < first_released_timestamp_other
      ECOSYSTEM_QUOTA * 0.97
    elsif current_timestamp >= first_released_timestamp_other && current_timestamp < second_released_timestamp_other
      ECOSYSTEM_QUOTA * 0.75
    elsif current_timestamp >= second_released_timestamp_other && current_timestamp < third_released_timestamp_other
      ECOSYSTEM_QUOTA * 0.5
    else
      0
    end
  end

  def team_locked
    if current_timestamp < first_released_timestamp_may
      TEAM_QUOTA * (2 / 3.to_d)
    elsif current_timestamp >= first_released_timestamp_may && current_timestamp < second_released_timestamp_may
      TEAM_QUOTA * 0.5
    elsif current_timestamp >= second_released_timestamp_may && current_timestamp < third_released_timestamp_may
      TEAM_QUOTA * (1 / 3.to_d)
    else
      0
    end
  end

  def private_sale_locked
    current_timestamp < first_released_timestamp_may ? PRIVATE_SALE_QUOTA * (1 / 3.to_d) : 0
  end

  def founding_partners_locked
    if current_timestamp < first_released_timestamp_may
      FOUNDING_PARTNER_QUOTA
    elsif current_timestamp >= first_released_timestamp_may && current_timestamp < second_released_timestamp_may
      FOUNDING_PARTNER_QUOTA * 0.75
    elsif current_timestamp >= second_released_timestamp_may && current_timestamp < third_released_timestamp_may
      FOUNDING_PARTNER_QUOTA * 0.5
    else
      0
    end
  end

  def foundation_reserve_locked
    current_timestamp < first_released_timestamp_other ? FOUNDATION_RESERVE_QUOTA : 0
  end

  def bug_bounty_locked
    Address.find_by_address_hash("ckb1qyqy6mtud5sgctjwgg6gydd0ea05mr339lnslczzrc")&.balance.to_i
  end

  private

  def tip_block
    @tip_block ||= tip_block_number.present? ? Block.find_by(number: tip_block_number) : Block.recent.first
  end

  def parsed_dao
    @parsed_dao ||= CkbUtils.parse_dao(tip_block.dao)
  end

  def total_supply
    if current_timestamp > first_released_timestamp_may
      result = parsed_dao.c_i - BURN_QUOTA - yesterday_treasury_amount.to_i
    else
      result = parsed_dao.c_i - BURN_QUOTA
    end

    unit == "ckb" ? (result / 10**8).truncate(8) : result
  end

  def circulating_supply
    result = parsed_dao.c_i - parsed_dao.s_i - BURN_QUOTA - ecosystem_locked - team_locked - private_sale_locked - founding_partners_locked - foundation_reserve_locked - bug_bounty_locked

    unit == "ckb" ? (result / 10**8).truncate(8) : result
  end

  # 2020-05-01
  def first_released_timestamp_may
    @first_released_timestamp_may ||=
      begin
        Rails.cache.realize("first_released_timestamp_may") do
          lock_address = Address.find_by_address_hash("ckb1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn323t90gna20lusyshreg32qee4fhkt9jj2t6qrqzzqxzq8yqt8kmd9")
          lock_address.present? ? lock_address.lock_script.lock_info[:estimated_unlock_time].to_i : CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2020-05-01"))
        end
      end
  end

  # 2021-05-01
  def second_released_timestamp_may
    @second_released_timestamp_may ||=
      begin
        lock_address = Address.find_by_address_hash("ckb1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn323crn7nscet5sfwxjkzhexymfa4zntzt8vasvqzzqxzq8yq92pgkg")
        lock_address.present? ? lock_address.lock_script.lock_info[:estimated_unlock_time].to_i : CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2021-05-01"))
      end
  end

  # 2022-05-01
  def third_released_timestamp_may
    @third_released_timestamp_may ||=
      begin
        lock_address = Address.find_by_address_hash("ckb1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn32sl0qgva2l78fcnjt6x8kr8sln4lqs4twcpq4qzzqxzq8yq7hpadu")
        lock_address.present? ? lock_address.lock_script.lock_info[:estimated_unlock_time].to_i : CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2022-05-01"))
      end
  end

  # 2020-07-01
  def first_released_timestamp_other
    @first_released_timestamp_other ||=
      begin
        Rails.cache.realize("first_released_timestamp_may") do
          lock_address = Address.find_by_address_hash("ckb1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn32s3y29vjv73cfm8qax220dwwmpdccl4upy4s9qzzqxzq8yqyd09am")
          lock_address.present? ? lock_address.lock_script.lock_info[:estimated_unlock_time].to_i : CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2020-07-01"))
        end
      end
  end

  # 2020-12-31
  def second_released_timestamp_other
    @second_released_timestamp_other ||=
      begin
        lock_address = Address.find_by_address_hash("ckb1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn32sn23uga5m8u5v87q98vr29qa8tl0ruu84gqfqzzqxzq8yqc2dxk6")
        lock_address.present? ? lock_address.lock_script.lock_info[:estimated_unlock_time].to_i : CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2020-12-31"))
      end
  end

  # 2022-12-31
  def third_released_timestamp_other
    @third_released_timestamp_other ||=
      begin
        lock_address = Address.find_by_address_hash("ckb1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn32sdufwedw7a0w9dkvhpsah4mdk2gkfq63e0q6qzzqxzq8yqnqq85p")
        lock_address.present? ? lock_address.lock_script.lock_info[:estimated_unlock_time].to_i : CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2022-12-31"))
      end
  end

  def yesterday_treasury_amount
    DailyStatistic.order(:created_at_unixtimestamp).last.treasury_amount
  end
end

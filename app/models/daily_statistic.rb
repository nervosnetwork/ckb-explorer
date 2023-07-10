class DailyStatistic < ApplicationRecord
  include AttrLogics

  VALID_INDICATORS = %w(
    transactions_count addresses_count total_dao_deposit live_cells_count dead_cells_count avg_hash_rate avg_difficulty uncle_rate
    total_depositors_count address_balance_distribution total_tx_fee occupied_capacity daily_dao_deposit daily_dao_depositors_count
    circulation_ratio daily_dao_withdraw nodes_count circulating_supply burnt locked_capacity treasury_amount mining_reward
    deposit_compensation liquidity created_at_unixtimestamp
  ).freeze
  MILLISECONDS_IN_DAY = BigDecimal(24 * 60 * 60 * 1000)
  GENESIS_TIMESTAMP = 1573852190812

  attr_accessor :from_scratch

  scope :valid_indicators, -> { select(VALID_INDICATORS - %w(burnt liquidity created_at updated_at) + %w(id)) }
  scope :recent, -> { order("created_at_unixtimestamp desc nulls last") }
  scope :recent_year, -> {
                        where("created_at_unixtimestamp >= ? and created_at_unixtimestamp < ?", Time.current.beginning_of_year.to_i, Time.current.to_i)
                      }

  def from_scratch
    @from_scratch ||= false
  end

  def burnt
    treasury_amount.to_i + MarketData::BURN_QUOTA
  end

  def liquidity
    circulating_supply - total_dao_deposit.to_d
  end

  define_logic :transactions_count do
    CkbTransaction.tx_committed.created_between(started_at, ended_at).count
  end

  define_logic :addresses_count do
    if from_scratch
      Address.created_before(ended_at).count
    else
      Address.created_after(started_at).created_before(ended_at).count + yesterday_daily_statistic.addresses_count.to_i
    end
  end

  define_logic :block_timestamp do
    blocks_in_current_period.recent.pick(:timestamp)
  end

  define_logic :total_dao_deposit do
    total_dao_deposit = ""
    if from_scratch
      deposit_amount = DaoEvent.processed.deposit_to_dao.created_before(ended_at).sum(:value)
      withdraw_amount = DaoEvent.processed.withdraw_from_dao.created_before(ended_at).sum(:value)
      total_dao_deposit = deposit_amount - withdraw_amount
    else
      daily_dao_withdraw = @daily_dao_withdraw ||= DaoEvent.processed.withdraw_from_dao.created_after(started_at).created_before(ended_at).sum(:value)
      daily_dao_deposit = @daily_dao_deposit ||= DaoEvent.processed.deposit_to_dao.created_after(started_at).created_before(ended_at).sum(:value)
      total_dao_deposit = daily_dao_deposit - daily_dao_withdraw + yesterday_daily_statistic.total_dao_deposit.to_i
    end
    total_dao_deposit
  end

  define_logic :dao_depositors_count do
    dao_depositors_count = ""
    if from_scratch
      dao_depositors_count = total_depositors_count.to_i - DaoEvent.processed.take_away_all_deposit.created_before(ended_at).count
    else
      withdrawals_today = DaoEvent.processed.take_away_all_deposit.created_after(started_at).created_before(ended_at).count
      dao_depositors_count = daily_dao_depositors_count.to_i - withdrawals_today + yesterday_daily_statistic.dao_depositors_count.to_i
    end
    dao_depositors_count
  end

  define_logic :unclaimed_compensation do
    phase1_dao_interests + unmade_dao_interests
  end

  define_logic :claimed_compensation do
    claimed_compensation = 0
    if from_scratch
      CellOutput.nervos_dao_withdrawing.consumed_before(ended_at).find_each do |nervos_dao_withdrawing_cell|
        claimed_compensation += CkbUtils.dao_interest(nervos_dao_withdrawing_cell)
      end
    else
      claimed_compensation_today = 0

      CellOutput.nervos_dao_withdrawing.consumed_between(started_at,
                                                         ended_at).find_each do |nervos_dao_withdrawing_cell|
        claimed_compensation_today += CkbUtils.dao_interest(nervos_dao_withdrawing_cell)
      end

      claimed_compensation_today + yesterday_daily_statistic.claimed_compensation.to_i
    end
  end

  define_logic :average_deposit_time do
    interest_bearing_deposits = 0
    uninterest_bearing_deposits = 0
    sum_interest_bearing = 0
    sum_uninterest_bearing = 0

    CellOutput.nervos_dao_withdrawing.generated_before(ended_at).unconsumed_at(ended_at).find_each do |nervos_dao_withdrawing_cell|
      nervos_dao_withdrawing_cell_generated_tx = nervos_dao_withdrawing_cell.ckb_transaction
      nervos_dao_deposit_cell = nervos_dao_withdrawing_cell_generated_tx.cell_inputs.order(:id)[nervos_dao_withdrawing_cell.cell_index].previous_cell_output
      interest_bearing_deposits += nervos_dao_deposit_cell.capacity
      sum_interest_bearing += nervos_dao_deposit_cell.capacity * (nervos_dao_withdrawing_cell.block_timestamp - nervos_dao_deposit_cell.block_timestamp) / MILLISECONDS_IN_DAY
    end

    CellOutput.nervos_dao_deposit.generated_before(ended_at).unconsumed_at(ended_at).find_each do |nervos_dao_deposit_cell|
      uninterest_bearing_deposits += nervos_dao_deposit_cell.capacity

      sum_uninterest_bearing += nervos_dao_deposit_cell.capacity * (ended_at - nervos_dao_deposit_cell.block_timestamp) / MILLISECONDS_IN_DAY
    end

    total_deposits = interest_bearing_deposits + uninterest_bearing_deposits

    if total_deposits.zero?
      0
    else
      ((sum_interest_bearing + sum_uninterest_bearing) / total_deposits).truncate(3)
    end
  end

  define_logic :estimated_apc do
    DaoContract.default_contract.estimated_apc(current_tip_block.fraction_epoch)
  end

  define_logic :mining_reward do
    Block.created_before(ended_at).sum(:secondary_reward)
  end

  define_logic :deposit_compensation do
    unclaimed_compensation.to_i + claimed_compensation.to_i
  end

  define_logic :treasury_amount do
    parse_dao = CkbUtils.parse_dao(current_tip_block.dao)
    parse_dao.s_i - unmade_dao_interests
  end

  define_logic :live_cells_count do
    if from_scratch
      CellOutput.generated_before(ended_at).unconsumed_at(ended_at).count
    else
      CellOutput.generated_between(started_at, ended_at).count +
        yesterday_daily_statistic.live_cells_count.to_i - dead_cells_count_today
    end
  end

  define_logic :dead_cells_count do
    if from_scratch
      CellOutput.generated_before(ended_at).consumed_before(ended_at).count
    else
      dead_cells_count_today + yesterday_daily_statistic.dead_cells_count.to_i
    end
  end

  define_logic :avg_hash_rate do
    first_block_for_the_day = blocks_in_current_period.order("timestamp asc").first
    last_block_for_the_day = blocks_in_current_period.recent.first
    total_block_time = last_block_for_the_day.timestamp - first_block_for_the_day.timestamp

    BigDecimal(total_difficulties_for_the_day) / total_block_time
  end

  define_logic :avg_difficulty do
    BigDecimal(total_difficulties_for_the_day) / total_blocks_count
  end

  define_logic :uncle_rate do
    uncles_count = blocks_in_current_period.sum(:uncles_count)
    BigDecimal(uncles_count) / total_blocks_count
  end

  define_logic :total_depositors_count do
    @total_depositors_count ||=
      if from_scratch
        DaoEvent.processed.new_dao_depositor.created_before(ended_at).count
      else
        new_depositors_count_today = processed_dao_events_in_current_period.new_dao_depositor.count
        new_depositors_count_today + yesterday_daily_statistic.total_depositors_count.to_i
      end
  end

  define_logic :address_balance_distribution do
    max_n = 9
    ranges =
      (1..max_n).map do |n|
        if n == 1
          [0, 100]
        else
          [10**n, 10**(n + 1)]
        end
      end

    ranges.each_with_index.map do |range, index|
      begin_value = range[0] * 10**8
      end_value = range[1] * 10**8
      if index == max_n - 1
        addresses_count = Address.visible.where("balance > ?", begin_value).count
        total_addresses_count = Address.visible.where("balance > 0").count
      else
        addresses_count = Address.visible.where("balance > ? and balance <= ?", begin_value, end_value).count
        total_addresses_count = Address.visible.where("balance > 0 and balance <= ?", end_value).count
      end

      [range[1], addresses_count, total_addresses_count]
    end
  end

  define_logic :total_tx_fee do
    blocks_in_current_period.sum(:total_transaction_fee)
  end

  define_logic :occupied_capacity do
    CellOutput.generated_before(ended_at).unconsumed_at(ended_at).sum(:occupied_capacity)
  end

  define_logic :daily_dao_deposit do
    processed_dao_events_in_current_period.deposit_to_dao.sum(:value)
  end

  define_logic :daily_dao_depositors_count do
    processed_dao_events_in_current_period.new_dao_depositor.count
  end

  define_logic :daily_dao_withdraw do
    processed_dao_events_in_current_period.withdraw_from_dao.sum(:value)
  end

  define_logic :circulation_ratio do
    total_dao_deposit.to_i / circulating_supply
  end

  define_logic :total_supply do
    tip_dao = current_tip_block.dao
    tip_parse_dao = CkbUtils.parse_dao(tip_dao)
    treasury_amount = @treasury_amount ||=
      begin
        parse_dao = CkbUtils.parse_dao(current_tip_block.dao)
        parse_dao.s_i - unmade_dao_interests
      end
    tip_parse_dao.c_i - MarketData::BURN_QUOTA - treasury_amount
  end

  define_logic :circulating_supply do
    MarketData.new(indicator: "circulating_supply", tip_block_number: current_tip_block.number,
                   unit: "shannon").call
  end

  define_logic :block_time_distribution do
    step = 0.1
    max_n = 50 - step
    ranges = (0..max_n).step(0.1).map { |n| [n.round(2), (n + step).round(2)] }
    tip_block_number = current_tip_block.number
    interval = 49999
    start_block_number = [0, tip_block_number - interval].max

    ranges.map do |range|
      millisecond_start = range[0] * 1000
      millisecond_end = range[1] * 1000
      block_count = Block.where(
        number: start_block_number..tip_block_number
      ).where(
        block_time: (millisecond_start + 1)..millisecond_end
      ).count
      [range[1], block_count]
    end
  end

  define_logic :epoch_time_distribution do
    max_n = 119
    ranges = [[0, 180]] + (180..(180 + max_n)).map { |n| [n, n + 1] }
    ranges.each_with_index.map { |range, index|
      milliseconds_start = range[0] * 60 * 1000
      milliseconds_end = range[1] * 60 * 1000
      condition =
        if index.zero?
          1..milliseconds_end
        elsif index == max_n + 1
          (milliseconds_start + 1)..
        else
          (milliseconds_start + 1)..milliseconds_end
        end
      epoch_count = ::EpochStatistic.where(epoch_time: condition).count

      [range[1], epoch_count]
    }.compact
  end

  define_logic :epoch_length_distribution do
    max_n = 1700
    ranges = (700..max_n).step(100).map { |n| [n, n + 100] }
    tip_epoch_number = current_tip_block.epoch
    interval = 499
    start_epoch_number = [0, tip_epoch_number - interval].max

    ranges.each_with_index.map { |range, _index|
      epoch_count = ::EpochStatistic.where(
        epoch_number: start_epoch_number..tip_epoch_number
      ).where(
        epoch_length: (range[0] + 1)..range[1]
      ).count

      [range[1], epoch_count]
    }.compact
  end

  define_logic :locked_capacity do
    market_data = MarketData.new(tip_block_number: current_tip_block.number)
    market_data.ecosystem_locked +
      market_data.team_locked +
      market_data.private_sale_locked +
      market_data.founding_partners_locked +
      market_data.foundation_reserve_locked +
      market_data.bug_bounty_locked
  end

  private

  def to_be_counted_date
    @to_be_counted_date ||= Time.zone.at(created_at_unixtimestamp).beginning_of_day
  end

  def started_at
    @started_at ||= CkbUtils.time_in_milliseconds(to_be_counted_date.beginning_of_day)
  end

  def ended_at
    @ended_at ||= CkbUtils.time_in_milliseconds(to_be_counted_date.end_of_day) - 1
  end

  def current_tip_block
    @current_tip_block ||=
      if from_scratch
        Block.created_before(ended_at).recent.first
      else
        blocks_in_current_period.recent.first || Block.recent.first
      end
  end

  def phase1_dao_interests
    @phase1_dao_interests ||=
      begin
        total = 0
        CellOutput.nervos_dao_withdrawing.
          generated_before(ended_at).unconsumed_at(ended_at).find_each do |nervos_dao_withdrawing_cell|
          total += CkbUtils.dao_interest(nervos_dao_withdrawing_cell)
        end
        total
      end
  end

  def unmade_dao_interests
    @unmade_dao_interests ||=
      begin
        tip_dao = current_tip_block.dao
        total = 0
        CellOutput.nervos_dao_deposit.
          generated_before(ended_at).unconsumed_at(ended_at).find_each do |cell_output|
          total += DaoCompensationCalculator.new(cell_output, tip_dao).call
        end
        total
      end
  end

  def blocks_in_current_period
    @blocks_in_current_period ||= Block.created_between(started_at, ended_at)
  end

  def dead_cells_count_today
    @dead_cells_count_today ||= CellOutput.consumed_after(started_at).consumed_before(ended_at).count
  end

  def total_blocks_count
    @total_blocks_count ||= blocks_in_current_period.count
  end

  def epoch_numbers_for_the_day
    blocks_in_current_period.distinct(:epoch).pluck(:epoch)
  end

  def total_difficulties_for_the_day
    @total_difficulties_for_the_day ||=
      epoch_numbers_for_the_day.reduce(0) do |memo, epoch_number|
        scope = blocks_in_current_period.where(epoch: epoch_number)
        first_block_of_the_epoch = scope.order("timestamp asc").first
        last_block_of_the_epoch = scope.recent.first
        memo + first_block_of_the_epoch.difficulty * (last_block_of_the_epoch.number - first_block_of_the_epoch.number + 1)
      end
  end

  def dao_events_in_current_period
    @dao_events_in_current_period ||= DaoEvent.created_between(started_at, ended_at)
  end

  def processed_dao_events_in_current_period
    @processed_dao_events_in_current_period ||= dao_events_in_current_period.processed
  end

  def yesterday_daily_statistic
    @yesterday_daily_statistic ||=
      begin
        yesterday_statistic = ::DailyStatistic.where("created_at_unixtimestamp < ?",
                                                     to_be_counted_date.beginning_of_day.to_i).recent.first
        if to_be_counted_date.beginning_of_day.to_i == Time.at(GENESIS_TIMESTAMP / 1000).in_time_zone.beginning_of_day.to_i \
          || aggron_first_day? \
          || yesterday_statistic.blank?
          OpenStruct.new(addresses_count: 0, total_dao_deposit: 0, dao_depositors_count: 0,
                         unclaimed_compensation: 0, claimed_compensation: 0,
                         average_deposit_time: 0, mining_reward: 0, deposit_compensation: 0,
                         treasury_amount: 0, total_depositors_count: 0,
                         live_cells_count: 0, dead_cells_count: 0, occupied_capacity: 0)
        else
          yesterday_statistic
        end
      end
  end

  def aggron_first_day?
    genesis_block_timestamp = Block.find_by(number: 0).timestamp

    ENV["CKB_NET_MODE"] == "testnet" \
    && to_be_counted_date.beginning_of_day.to_i == Time.at(genesis_block_timestamp / 1000).in_time_zone.beginning_of_day.to_i
  end
end

# == Schema Information
#
# Table name: daily_statistics
#
#  id                           :bigint           not null, primary key
#  transactions_count           :string           default("0")
#  addresses_count              :string           default("0")
#  total_dao_deposit            :string           default("0.0")
#  block_timestamp              :decimal(30, )
#  created_at_unixtimestamp     :integer
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  dao_depositors_count         :string           default("0")
#  unclaimed_compensation       :string           default("0")
#  claimed_compensation         :string           default("0")
#  average_deposit_time         :string           default("0")
#  estimated_apc                :string           default("0")
#  mining_reward                :string           default("0")
#  deposit_compensation         :string           default("0")
#  treasury_amount              :string           default("0")
#  live_cells_count             :string           default("0")
#  dead_cells_count             :string           default("0")
#  avg_hash_rate                :string           default("0")
#  avg_difficulty               :string           default("0")
#  uncle_rate                   :string           default("0")
#  total_depositors_count       :string           default("0")
#  total_tx_fee                 :decimal(30, )
#  address_balance_distribution :jsonb
#  occupied_capacity            :decimal(30, )
#  daily_dao_deposit            :decimal(30, )
#  daily_dao_depositors_count   :integer
#  daily_dao_withdraw           :decimal(30, )
#  circulation_ratio            :decimal(, )
#  total_supply                 :decimal(30, )
#  circulating_supply           :decimal(, )
#  block_time_distribution      :jsonb
#  epoch_time_distribution      :jsonb
#  epoch_length_distribution    :jsonb
#  average_block_time           :jsonb
#  nodes_distribution           :jsonb
#  nodes_count                  :integer
#  locked_capacity              :decimal(30, )
#
# Indexes
#
#  index_daily_statistics_on_created_at_unixtimestamp  (created_at_unixtimestamp) UNIQUE
#

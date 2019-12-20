class DaoContract < ApplicationRecord
  validates :total_deposit, :interest_granted, :deposit_transactions_count, :withdraw_transactions_count, :depositors_count, :total_depositors_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  CONTRACT_NAME = "nervos_dao".freeze
  GENESIS_ISSUANCE = 336 * 10**8
  ANNUAL_PRIMARY_ISSUANCE_BASE = GENESIS_ISSUANCE / 8
  PRIMARY_ISSUANCE_PER_YEAR_BASE = BigDecimal(42 * 10**8)
  EPOCHS_IN_ONE_NATURAL_YEAR = 2190
  YEARS_IN_PERIOD = 4
  EPOCHS_IN_PERIOD = BigDecimal(EPOCHS_IN_ONE_NATURAL_YEAR * YEARS_IN_PERIOD)
  SECONDARY_ISSUANCE_PER_EPOCH = BigDecimal(1344 * 10**6) / 2190

  def self.default_contract
    find_or_create_by(id: 1)
  end

  def ckb_transactions
    ckb_transaction_ids = CellOutput.nervos_dao_deposit.pluck("generated_by_id") + CellOutput.nervos_dao_withdrawing.pluck("generated_by_id") + CellOutput.nervos_dao_withdrawing.pluck("consumed_by_id").compact
    CkbTransaction.where(id: ckb_transaction_ids.uniq)
  end

  def estimated_apc(deposit_epoch, deposited_epochs = EPOCHS_IN_ONE_NATURAL_YEAR)
    start_epoch_number = deposit_epoch.number
    end_epoch_number = start_epoch_number + deposited_epochs - 1
    checkpoint_start =(start_epoch_number / EPOCHS_IN_PERIOD).ceil * EPOCHS_IN_PERIOD
    checkpoint_end = (end_epoch_number / EPOCHS_IN_PERIOD).floor * EPOCHS_IN_PERIOD
    checkpoints_size = (checkpoint_end - checkpoint_start) / EPOCHS_IN_PERIOD + 1
    checkpoints = checkpoints_size.to_i.times.map { |index| (index * EPOCHS_IN_PERIOD + checkpoint_start - 1).to_i }

    checkpoints.unshift(start_epoch_number.to_i) if checkpoints.empty? || checkpoints[0] > start_epoch_number
    checkpoints.push(end_epoch_number.to_i) if checkpoints.last < end_epoch_number
    end_epoch_numbers = checkpoints[1..-1]
    rates = end_epoch_numbers.each_with_index.map do |inner_end_epoch_number, index|
      epoch_index = deposit_epoch.index * 1800 / deposit_epoch.length
      start_epoch = OpenStruct.new(number: checkpoints[index], index: epoch_index, length: 1800)
      end_epoch = OpenStruct.new(number: inner_end_epoch_number, index: epoch_index, length: 1800)
      rate(start_epoch, end_epoch)
    end

    rates.reduce(1) { |memo, rate| memo * (1 + rate) } - 1
  end

  private

  def alpha(start_epoch_number)
    i = ((start_epoch_number + 1) / EPOCHS_IN_PERIOD).floor
    p = PRIMARY_ISSUANCE_PER_YEAR_BASE / 2 ** i / 2190
    p / SECONDARY_ISSUANCE_PER_EPOCH
  end

  def rate(start_epoch, end_epoch)
    alpha = alpha(start_epoch.number)
    sn = SECONDARY_ISSUANCE_PER_EPOCH * ((end_epoch.number + end_epoch.index / end_epoch.length) - (start_epoch.number + start_epoch.index / start_epoch.length))
    Math.log(1 + (alpha + 1) * sn / total_issuance(start_epoch)) / (alpha + 1)
  end

  def total_issuance(start_epoch)
    primary_issuance(start_epoch) + secondary_issuance(start_epoch)
  end

  def primary_issuance(start_epoch)
    epochs = (start_epoch.number / EPOCHS_IN_PERIOD).floor
    epochs.times.reduce(GENESIS_ISSUANCE) { |memo, item| memo + (ANNUAL_PRIMARY_ISSUANCE_BASE * YEARS_IN_PERIOD) / 2 ** item } \
      + (ANNUAL_PRIMARY_ISSUANCE_BASE * ((start_epoch.number + 1 - epochs * EPOCHS_IN_PERIOD) / EPOCHS_IN_ONE_NATURAL_YEAR)) / 2 ** epochs
  end

  def secondary_issuance(start_epoch)
    deposit_fraction = start_epoch.number + (start_epoch.index / start_epoch.length)
    epochs = deposit_fraction > 0 ? (deposit_fraction + 1) : deposit_fraction
    epochs * SECONDARY_ISSUANCE_PER_EPOCH
  end
end

# == Schema Information
#
# Table name: dao_contracts
#
#  id                          :bigint           not null, primary key
#  total_deposit               :decimal(30, )    default(0)
#  interest_granted            :decimal(30, )    default(0)
#  deposit_transactions_count  :bigint           default(0)
#  withdraw_transactions_count :bigint           default(0)
#  depositors_count            :integer          default(0)
#  total_depositors_count      :bigint           default(0)
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#

# Refresh average deposit time for each address
# average_deposit_time = Average locked duration of *each CKByte* in DAO Deposit
# so we must sum the locked duration of all each CKByte in locked and unlocked deposit cells.
class AddressAverageDepositTimeGenerator
  MilliSecondsInDay = BigDecimal(24 * 60 * 60 * 1000).freeze
  include Sidekiq::Worker

  def perform
    addresses = Address.where(is_depositor: true).to_a
    addresses.each do |address|
      address.average_deposit_time = cal_average_deposit_time(address)
      address.save
    end
  end

  # return average deposit time of specific address (unit in day)
  def cal_average_deposit_time(address, ended_at = CkbUtils.time_in_milliseconds(Time.current))
    total_ckb_deposit_time = 0 #   unlocked CKBs
    total_deposits = 0 # locked CKBs

    # for unlocked deposit cell
    # we must calculate the locked duration from lock to unlock.
    # for locking deposit cell
    # we calculate the locked duration from lock to now.
    address.cell_outputs.nervos_dao_deposit.each do |cell|
      total_deposits += cell.capacity
      total_ckb_deposit_time += cell.capacity * ((cell.consumed_by_id ? cell.consumed_block_timestamp : ended_at) - cell.block_timestamp)
    end

    return 0 if total_deposits.zero?

    (total_ckb_deposit_time / total_deposits / MilliSecondsInDay).truncate(6)
  end
end

class AddressAverageDepositTimeGenerator
  include Sidekiq::Worker

  def perform
    addresses = Address.where("dao_deposit > 0")
    values =
      addresses.map do |address|
        [address.id, cal_average_deposit_time(address)]
      end
    columns = [:id, :average_deposit_time]

    Address.import! columns, values, validate: false, on_duplicate_key_update: [:average_deposit_time]
  end

  private

  def cal_average_deposit_time(address)
    interest_bearing_deposits = 0
    uninterest_bearing_deposits = 0
    milliseconds_in_day = BigDecimal(24 * 60 * 60 * 1000)
    ended_at = CkbUtils.time_in_milliseconds(Time.current)
    sum_interest_bearing =
      address.cell_outputs.nervos_dao_withdrawing.unconsumed_at(ended_at).reduce(0) do |memo, nervos_dao_withdrawing_cell|
        nervos_dao_withdrawing_cell_generated_tx = nervos_dao_withdrawing_cell.generated_by
        nervos_dao_deposit_cell = nervos_dao_withdrawing_cell_generated_tx.cell_inputs.order(:id)[nervos_dao_withdrawing_cell.cell_index].previous_cell_output
        interest_bearing_deposits += nervos_dao_deposit_cell.capacity
        memo + nervos_dao_deposit_cell.capacity * (nervos_dao_withdrawing_cell.block_timestamp - nervos_dao_deposit_cell.block_timestamp) / milliseconds_in_day
      end
    sum_uninterest_bearing =
      address.cell_outputs.nervos_dao_deposit.unconsumed_at(ended_at).reduce(0) do |memo, nervos_dao_deposit_cell|
        uninterest_bearing_deposits += nervos_dao_deposit_cell.capacity

        memo + nervos_dao_deposit_cell.capacity * (ended_at - nervos_dao_deposit_cell.block_timestamp) / milliseconds_in_day
      end

    (sum_interest_bearing + sum_uninterest_bearing) / (interest_bearing_deposits + uninterest_bearing_deposits)
  end
end

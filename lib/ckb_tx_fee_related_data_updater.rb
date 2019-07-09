require_relative "../config/environment"

loop do
  next if Sidekiq::Queue.new("tx_fee_updater").size > 2000

  need_update_cell_inputs = CellInput.where(from_cell_base: false, previous_cell_output_id: nil).limit(1000)

  next if need_update_cell_inputs.blank?

  block_ids = need_update_cell_inputs.pluck(:block_id).map { |id| [id] }
  Sidekiq::Client.push_bulk("class" => "UpdateTxFeeWorker", "args" => block_ids, "queue" => "tx_fee_updater")

  sleep(ENV["TX_FEE_UPDATER_LOOP_INTERVAL"].to_i)
end

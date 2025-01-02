namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:check_dao_event"
  task check_dao_event: :environment do
    error_tx_ids = []
    CkbTransaction.where("tags @> array[?]::varchar[]", ["dao"]).find_each do |tx|
      tx.outputs.where(cell_type: :nervos_dao_deposit).each do |output|
        unless DaoEvent.where(ckb_transaction_id: tx.id, address_id: output.address_id, value: output.capacity, event_type: "deposit_to_dao", cell_index: output.cell_index).exists?
          error_tx_ids << tx.id
        end
      end
      tx.cell_inputs.where(cell_type: :nervos_dao_withdrawing).each do |input|
        previous_cell_output = CellOutput.
          where(id: input.previous_cell_output_id).
          select(:address_id, :block_id, :ckb_transaction_id, :dao, :cell_index, :capacity, :occupied_capacity).
          take!
        interest = CkbUtils.dao_interest(previous_cell_output)
        unless DaoEvent.where(ckb_transaction_id: tx.id, address_id: previous_cell_output.address_id, value: interest, event_type: "issue_interest", cell_index: input.index).exists?
          error_tx_ids << tx.id

        end
      end
      tx.cell_inputs.where(cell_type: :nervos_dao_deposit).each do |input|
        previous_cell_output =
          CellOutput.
            where(id: input.previous_cell_output_id).
            select(:address_id, :ckb_transaction_id, :cell_index, :capacity).
            take!
        unless DaoEvent.where(ckb_transaction_id: tx.id, address_id: previous_cell_output.address_id, value: previous_cell_output.capacity, event_type: "withdraw_from_dao",
                              cell_index: input.index).exists?
          error_tx_ids << tx.id
        end
      end
    end
    puts error_tx_ids.join(",")
  end
end

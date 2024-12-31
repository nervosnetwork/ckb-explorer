namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_cell_index_to_dao_event"
  task fill_cell_index_to_dao_event: :environment do
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")
    CellOutput.includes(:cell_inputs).dead.where(cell_type: ["nervos_dao_deposit", "nervos_dao_withdrawing"]).find_each do |output|
      input = output.cell_inputs.first
      if input.cell_type != output.cell_type
        puts "input id: #{input.id}"
        input.update(cell_type: output.cell_type)
      end
    end
    CkbTransaction.where("tags @> array[?]::varchar[]", ["dao"]).find_each do |tx|
      tx.outputs.where(cell_type: :nervos_dao_deposit).each do |output|
        unless DaoEvent.where(ckb_transaction_id: tx.id, address_id: output.address_id, value: output.capacity, event_type: "deposit_to_dao", cell_index: output.cell_index).exists?
          event = DaoEvent.where(ckb_transaction_id: tx.id, address_id: output.address_id, value: output.capacity, event_type: "deposit_to_dao", cell_index: nil).limit(1).first
          if event
            event.update(cell_index: output.cell_index)
          else
            DaoEvent.create(ckb_transaction_id: tx.id, address_id: output.address_id, value: output.capacity, event_type: "deposit_to_dao", status: "processed", cell_index: output.cell_index, block_id: tx.block_id,
                            block_timestamp: tx.block_timestamp, contract_id: 1)
          end
        end
      end
      tx.cell_inputs.where(cell_type: :nervos_dao_withdrawing).each do |input|
        previous_cell_output = CellOutput.
          where(id: input.previous_cell_output_id).
          select(:address_id, :block_id, :ckb_transaction_id, :dao, :cell_index, :capacity, :occupied_capacity).
          take!
        interest = CkbUtils.dao_interest(previous_cell_output)
        unless DaoEvent.where(ckb_transaction_id: tx.id, address_id: previous_cell_output.address_id, value: interest, event_type: "issue_interest", cell_index: input.index).exists?
          event = DaoEvent.where(ckb_transaction_id: tx.id, address_id: previous_cell_output.address_id, value: interest, event_type: "issue_interest", cell_index: nil).limit(1).first
          if event
            event.update(cell_index: input.index)
          else
            DaoEvent.create(ckb_transaction_id: tx.id, address_id: previous_cell_output.address_id, value: interest, event_type: "issue_interest", status: "processed", cell_index: input.index, block_id: tx.block_id,
                            block_timestamp: tx.block_timestamp, contract_id: 1)
          end
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
          event = DaoEvent.where(ckb_transaction_id: tx.id, address_id: previous_cell_output.address_id, value: previous_cell_output.capacity, event_type: "withdraw_from_dao",
                                 cell_index: nil).limit(1).first
          if event
            event.update(cell_index: input.index)
          else
            DaoEvent.create(ckb_transaction_id: tx.id, address_id: previous_cell_output.address_id, value: previous_cell_output.capacity, event_type: "withdraw_from_dao", status: "processed", cell_index: input.index, block_id: tx.block_id,
                            block_timestamp: tx.block_timestamp, contract_id: 1)
          end
        end
      end
    end
  end
end

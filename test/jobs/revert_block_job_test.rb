require "test_helper"

class RevertBlockJobTest < ActiveJob::TestCase
  setup do
    @address = create(:address)
    first_block = create(:block, address_ids: [@address.id], number: 10)
    tx = create(:ckb_transaction, block: first_block)
    dao_type_script = create(:type_script, code_hash: Settings.dao_code_hash, hash_type: "type")
    previous_cell_output1 = create(:cell_output, block_id: first_block.id, block_timestamp: first_block.timestamp, ckb_transaction: tx, address: @address, capacity: 1000 * (10**8), cell_index: 0)
    previous_cell_output2 = create(:cell_output, block_id: first_block.id, block_timestamp: first_block.timestamp, ckb_transaction: tx, address: @address, capacity: 3000 * (10**8), data_hash: CKB::Utils.bin_to_hex("\x00" * 8),
                                                 cell_type: "nervos_dao_deposit", type_script_id: dao_type_script.id, cell_index: 1)
    previous_cell_output3 = create(:cell_output, block_id: first_block.id, block_timestamp: first_block.timestamp, ckb_transaction: tx, address: @address, capacity: 1000 * (10**8), cell_index: 2)
    previous_cell_output4 = create(:cell_output, block_id: first_block.id, block_timestamp: first_block.timestamp, ckb_transaction: tx, address: @address, capacity: 1000 * (10**8), cell_index: 3)

    deposit_dao_event = create(:dao_event, block_id: first_block.id, block_timestamp: first_block.timestamp, ckb_transaction_id: tx.id, address_id: @address.id, value: 3000 * (10**8),
                                           event_type: "deposit_to_dao")

    @address.update(balance: 6000 * (10**8), balance_occupied: 3000 * (10**8), live_cells_count: 4, ckb_transactions_count: 1, last_updated_block_number: first_block.number)
    @parent_block = create(:block, parent_hash: first_block.hash, address_ids: [@address.id], number: 11)
    parent_tx = create(:ckb_transaction, block: @parent_block)
    create(:cell_input, block_id: @parent_block.id, ckb_transaction: parent_tx, previous_cell_output_id: previous_cell_output1.id, index: 0)
    create(:cell_input, block_id: @parent_block.id, ckb_transaction: parent_tx, previous_cell_output_id: previous_cell_output2.id, index: 1)
    create(:cell_input, block_id: @parent_block.id, ckb_transaction: parent_tx, previous_cell_output_id: previous_cell_output3.id, index: 2)
    previous_cell_output1.update(status: "dead", consumed_by_id: parent_tx.id, consumed_block_timestamp: @parent_block.timestamp)
    previous_cell_output2.update(status: "dead", consumed_by_id: parent_tx.id, consumed_block_timestamp: @parent_block.timestamp)
    previous_cell_output3.update(status: "dead", consumed_by_id: parent_tx.id, consumed_block_timestamp: @parent_block.timestamp)
    previous_cell_output4.update(status: "dead", consumed_by_id: parent_tx.id, consumed_block_timestamp: @parent_block.timestamp)
    create(:cell_output, block_id: @parent_block.id, block_timestamp: @parent_block.timestamp, ckb_transaction: parent_tx, address: @address, capacity: 2000 * (10**8), cell_index: 0)
    create(:cell_output, block_id: @parent_block.id, block_timestamp: @parent_block.timestamp, ckb_transaction: parent_tx, address: @address, capacity: 3000 * (10**8),
                         data_hash: "0x0000000000000000000000000000000000000000000000000000000000000000042", cell_type: "nervos_dao_withdrawing", type_script_id: dao_type_script.id, cell_index: 1)
    deposit_dao_event.update(consumed_block_timestamp: @parent_block.timestamp, consumed_transaction_id: parent_tx.id)
    create(:dao_event, block_id: @parent_block.id, block_timestamp: @parent_block.timestamp, ckb_transaction_id: parent_tx.id, address_id: @address.id, value: 3000 * (10**8),
                       event_type: "withdraw_from_dao")
    @address.update(balance: 5000 * (10**8), balance_occupied: 3000 * (10**8), live_cells_count: 2, ckb_transactions_count: 2, last_updated_block_number: @parent_block.number)
  end
end

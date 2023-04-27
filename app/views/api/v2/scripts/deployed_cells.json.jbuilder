json.data do
  json.deployed_cells @deployed_cells do |deployed_cell|
    cell_output = deployed_cell.cell_output
    json.id deployed_cell.cell_output.id
    json.capacity deployed_cell.cell_output.capacity
    json.ckb_transaction_id deployed_cell.cell_output.ckb_transaction_id
    json.created_at deployed_cell.cell_output.created_at
    json.updated_at deployed_cell.cell_output.updated_at
    json.status cell_output.status
    json.address_id cell_output.address_id
    json.block_id cell_output.block_id
    json.tx_hash cell_output.tx_hash
    json.cell_index cell_output.cell_index
    json.consumed_by_id cell_output.consumed_by_id
    json.cell_type cell_output.cell_type
    json.data_size cell_output.data_size
    json.occupied_capacity cell_output.occupied_capacity
    json.block_timestamp cell_output.block_timestamp
    json.consumed_block_timestamp cell_output.consumed_block_timestamp
    json.type_hash cell_output.type_hash
    json.udt_amount cell_output.udt_amount
    json.dao cell_output.dao
    json.lock_script_id cell_output.lock_script_id
    json.type_script_id cell_output.type_script_id
  end
  json.meta do
    json.total @deployed_cells.count
    json.page_size @page_size.to_i
  end
end

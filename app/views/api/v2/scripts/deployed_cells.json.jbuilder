json.data do
  json.deployed_cells @deployed_cells do |deployed_cell|
    json.id deployed_cell.id
    json.capacity deployed_cell.capacity
    json.ckb_transaction_id deployed_cell.ckb_transaction_id
    json.created_at deployed_cell.created_at
    json.updated_at deployed_cell.updated_at
    json.status deployed_cell.status
    json.address_id deployed_cell.address_id
    json.block_id deployed_cell.block_id
    json.tx_hash deployed_cell.tx_hash
    json.cell_index deployed_cell.cell_index
    json.consumed_by_id deployed_cell.consumed_by_id
    json.cell_type deployed_cell.cell_type
    json.data_size deployed_cell.data_size
    json.occupied_capacity deployed_cell.occupied_capacity
    json.block_timestamp deployed_cell.block_timestamp
    json.consumed_block_timestamp deployed_cell.consumed_block_timestamp
    json.type_hash deployed_cell.type_hash
    json.udt_amount deployed_cell.udt_amount
    json.dao deployed_cell.dao
    json.lock_script_id deployed_cell.lock_script_id
    json.type_script_id deployed_cell.type_script_id
  end
  json.meta do
    json.total @contract.deployed_cells_count
    json.page_size @page_size.to_i
  end
end

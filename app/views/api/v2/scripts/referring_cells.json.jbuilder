json.data do
  json.referring_cells @referring_cells do |referring_cell|
    json.id referring_cell.id
    json.capacity referring_cell.capacity
    json.ckb_transaction_id referring_cell.ckb_transaction_id
    json.created_at referring_cell.created_at
    json.updated_at referring_cell.updated_at
    json.status referring_cell.status
    json.address_id referring_cell.address_id
    json.block_id referring_cell.block_id
    json.tx_hash referring_cell.tx_hash
    json.cell_index referring_cell.cell_index
    json.consumed_by_id referring_cell.consumed_by_id
    json.cell_type referring_cell.cell_type
    json.data_size referring_cell.data_size
    json.occupied_capacity referring_cell.occupied_capacity
    json.block_timestamp referring_cell.block_timestamp
    json.consumed_block_timestamp referring_cell.consumed_block_timestamp
    json.type_hash referring_cell.type_hash
    json.udt_amount referring_cell.udt_amount
    json.dao referring_cell.dao
    json.lock_script_id referring_cell.lock_script_id
    json.type_script_id referring_cell.type_script_id
  end
  json.meta do
    json.total @contract.referring_cells_count
    json.page_size @page_size.to_i
  end
end

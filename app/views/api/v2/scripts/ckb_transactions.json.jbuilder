json.data do
  json.ckb_transactions @ckb_transactions do |tx|
    json.id tx.id
    json.tx_hash tx.tx_hash
    json.block_id tx.block_id
    json.block_number tx.block_number
    json.block_timestamp tx.block_timestamp
    json.transaction_fee tx.transaction_fee
    json.is_cellbase tx.is_cellbase
    json.header_deps tx.header_deps
    json.cell_deps tx.cell_deps
    json.witnesses tx.witnesses
    json.live_cell_changes tx.live_cell_changes
    json.capacity_involved tx.capacity_involved
    json.contained_address_ids tx.contained_address_ids
    json.tags tx.tags
    json.contained_udt_ids tx.contained_udt_ids
    json.dao_address_ids tx.contained_dao_address_ids
    json.udt_address_ids tx.contained_udt_address_ids
    json.bytes tx.bytes
    json.tx_status tx.tx_status
    json.display_inputs tx.display_inputs
    json.display_outputs tx.display_outputs
  end
  json.meta do
    json.total @total || @contract.ckb_transactions.count
    json.page_size @page_size.to_i
  end
end

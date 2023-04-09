class ScriptsCkbTransactionsSerializer
  include FastJsonapi::ObjectSerializer

  def to_json(tx)
    {
      id: tx.id,
      tx_hash: tx.tx_hash,
      block_id: tx.block_id,
      block_number: tx.block_number,
      block_timestamp: tx.block_timestamp,
      transaction_fee: tx.transaction_fee,
      is_cellbase: tx.is_cellbase,
      header_deps: tx.header_deps,
      cell_deps: tx.cell_deps,
      witnesses: tx.witnesses,
      live_cell_changes: tx.live_cell_changes,
      capacity_involved: tx.capacity_involved,
      contained_address_ids: tx.contained_address_ids,
      tags: tx.tags,
      contained_udt_ids: tx.contained_udt_ids,
      dao_address_ids: tx.contained_dao_address_ids,
      udt_address_ids: tx.contained_udt_address_ids,
      bytes: tx.bytes,
      tx_status: tx.tx_status,
      display_inputs: tx.display_inputs,
      display_outputs: tx.display_outputs
    }
  end
end

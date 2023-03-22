class CellOutputWithoutDataSerializer
  include FastJsonapi::ObjectSerializer

  def to_json cell_output
    {
      id: cell_output.id,
      capacity: cell_output.capacity,
      ckb_transaction_id: cell_output.ckb_transaction_id,
      created_at: cell_output.created_at,
      updated_at: cell_output.updated_at,
      status: cell_output.status,
      address_id: cell_output.address_id,
      block_id: cell_output.block_id,
      tx_hash: cell_output.tx_hash,
      cell_index: cell_output.cell_index,
      generated_by_id: cell_output.generated_by_id,
      consumed_by_id: cell_output.consumed_by_id,
      cell_type: cell_output.cell_type,
      data_size: cell_output.data_size,
      occupied_capacity: cell_output.occupied_capacity,
      block_timestamp: cell_output.block_timestamp,
      consumed_block_timestamp: cell_output.consumed_block_timestamp,
      type_hash: cell_output.type_hash,
      udt_amount: cell_output.udt_amount,
      dao: cell_output.dao,
      lock_script_id: cell_output.lock_script_id,
      type_script_id: cell_output.type_script_id
    }
  end
end

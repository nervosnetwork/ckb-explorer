json.data do
  json.ckb_transactions @bitcoin_annotations do |annotation|
    tx = annotation.ckb_transaction

    json.id tx.id
    json.tx_hash tx.tx_hash
    json.block_id tx.block_id
    json.block_number tx.block_number
    json.block_timestamp tx.block_timestamp
    json.leap_direction tx.leap_direction
    json.transfer_step tx.transfer_step
    json.rgb_cell_changes tx.rgb_cell_changes
    json.rgb_txid tx.rgb_txid
  end
end
json.meta do
  json.total @bitcoin_annotations.total_count
  json.page_size @bitcoin_annotations.current_per_page
end

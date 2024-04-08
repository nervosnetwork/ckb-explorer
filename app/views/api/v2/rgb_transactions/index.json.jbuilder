json.data do
  json.ckb_transactions @ckb_transactions do |tx|
    json.id tx.id
    json.tx_hash tx.tx_hash
    json.block_id tx.block_id
    json.block_number tx.block_number
    json.block_timestamp tx.block_timestamp
    json.leap_direction tx.leap_direction
    json.rgb_cell_changes tx.rgb_cell_changes
    json.tgb_txid tx.rgb_txid
  end
end
json.meta do
  json.total @ckb_transactions.total_count
  json.page_size @ckb_transactions.current_per_page
end

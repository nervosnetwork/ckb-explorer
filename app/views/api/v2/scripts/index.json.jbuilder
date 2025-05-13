json.data do
  json.array! @contracts do |contract|
    json.type_hash contract.type_hash
    json.data_hash contract.data_hash
    json.hash_type contract.hash_type
    json.tx_hash "#{contract.deployed_cell_output.tx_hash}-#{contract.deployed_cell_output.cell_index}"
    json.dep_type contract.dep_type
    json.name contract.name
    json.is_type_script contract.is_type_script
    json.is_lock_script contract.is_lock_script
    json.deprecated contract.deprecated
    json.deployed_block_timestamp contract.deployed_block_timestamp
    json.total_referring_cells_capacity contract.total_referring_cells_capacity.to_s
  end
end
json.meta do
  json.total @contracts.total_count
  json.page_size @page_size.to_i
end

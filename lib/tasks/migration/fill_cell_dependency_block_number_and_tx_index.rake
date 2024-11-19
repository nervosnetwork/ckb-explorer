namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_cell_dependency_block_number_and_tx_index[0,10000]"
  task :fill_cell_dependency_block_number_and_tx_index, %i[start_block end_block] => :environment do |_, args|
    $retry_ids = Set.new
    @api = CKB::API.new(host: ENV["CKB_NODE_URL"],
                        timeout_config: {
                          open_timeout: 1, read_timeout: 3,
                          write_timeout: 1
                        })
    (args[:start_block].to_i..args[:end_block].to_i).to_a.each_slice(100).to_a.each do |range|
      compare_cell_dependency(range, 0)
    end; nil

    puts "retry IDS:"
    puts $retry_ids.join(",")
    puts "done"
  end

  def compare_cell_dependency(range, retry_count)
    request_body =
      range.map do |number|
        ["get_block_by_number", number]
      end
    response = @api.batch_request(*request_body)
    response.each do |r|
      attrs = []
      r[:transactions].each do |tx|
        if tx[:cell_deps].length > 0
          local_tx = CkbTransaction.find_by(tx_hash: tx[:hash])
          tx[:cell_deps].map do |cell_dep|
            co = CellOutput.find_by(tx_hash: cell_dep[:out_point][:tx_hash], cell_index: (cell_dep[:out_point][:index]).to_i(16))
            attrs << { block_number: local_tx.block_number, tx_index: local_tx.tx_index, contract_cell_id: co.id, dep_type: cell_dep[:dep_type], ckb_transaction_id: local_tx.id }
          end
        end
      end; nil
      CellDependency.upsert_all(attrs, unique_by: %i[ckb_transaction_id contract_cell_id], update_only: %i[block_number tx_index]) if attrs.present?
    end; nil
  rescue StandardError => _e
    retry_count += 1
    if retry_count > 2
      $retry_ids << range.first
    else
      compare_cell_dependency(range, retry_count)
    end
  end
end

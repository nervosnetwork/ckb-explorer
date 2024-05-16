namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:comprare_output_with_rpc[0,10000]"
  task :comprare_output_with_rpc, %i[start_block end_block] => :environment do |_, args|
    $redundant_output_txs = Set.new
    $error_ids = Set.new
    $retry_ids = Set.new
    @api = CKB::API.new(host: ENV["CKB_NODE_URL"],
                        timeout_config: {
                          open_timeout: 1, read_timeout: 3,
                          write_timeout: 1
                        })
    (args[:start_block].to_i..args[:end_block].to_i).to_a.each_slice(100).to_a.each do |range|
      compare_output(range, 0)
    end; nil

    puts "redundant output txs"
    puts $redundant_output_txs.join(",")
    puts "error IDS:"
    puts $error_ids.join(",")
    puts "retry IDS:"
    puts $retry_ids.join(",")
    puts "done"
  end

  def compare_output(range, retry_count)
    request_body =
      range.map do |number|
        ["get_block_by_number", number]
      end
    response = @api.batch_request(*request_body)
    response.each do |r|
      r[:transactions].each do |tx|
        if CellOutput.where(tx_hash: tx[:hash]).count != tx[:outputs].count
          rpc_results = []
          tx[:outputs].each_with_index do |_output, index|
            rpc_results << ["#{tx[:hash]}", index]
          end
          db_results = CellOutput.where(tx_hash: tx[:hash]).pluck(:tx_hash, :cell_index)
          different = rpc_results - db_results | db_results - rpc_results
          different.each do |d|
            $redundant_output_txs << d.join("-")
          end
        end
        tx[:inputs].each do |input|
          unless input[:previous_output][:tx_hash] == "0x0000000000000000000000000000000000000000000000000000000000000000"
            result = CellOutput.where(tx_hash: input[:previous_output][:tx_hash], cell_index: input[:previous_output][:index].to_i(16), status: :dead).exists?
            unless result
              $error_ids << number
            end
          end
        end
        tx[:outputs].each_with_index do |output, index|
          db_output = CellOutput.find_by(tx_hash: tx[:hash], cell_index: index)
          if db_output.nil? || db_output.capacity != output.capacity
            $error_ids << number
          end
        end; nil
      end; nil
    end; nil
  rescue StandardError => _e
    retry_count += 1
    if retry_count > 2
      $retry_ids << range.first
    else
      compare_output(range, retry_count)
    end
  end
end

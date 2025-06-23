namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:check_cell_output_data[0,1000000]"
  task :check_cell_output_data, %i[start_block end_block] => :environment do |_, args|
    $retry_ids = Set.new
    @api = CKB::API.new(host: ENV.fetch("CKB_NODE_URL", nil),
                        timeout_config: {
                          open_timeout: 1, read_timeout: 3,
                          write_timeout: 1
                        })
    (args[:start_block].to_i..args[:end_block].to_i).to_a.each_slice(100).to_a.each do |range|
      compare_output(range, 0)
    end
    nil

    puts "=============="
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
        tx[:outputs].each_with_index do |_output, index|
          output_data = tx[:outputs_data][index]
          binary_data = CKB::Utils.hex_to_bin(output_data)
          data_hash = nil
          data_size = 0
          if binary_data&.bytesize&.positive?
            data_size = binary_data.bytesize
            data_hash = CKB::Utils.bin_to_hex(CKB::Blake2b.digest(binary_data))
          end
          co = CellOutput.find_by(tx_hash: tx[:hash], cell_index: index)

          if co.data_size != data_size || co.data_hash != data_hash
            puts co.id
            co.update!(data_hash:, data_size:)
            if data_size.zero?
              co.cell_datum.destroy if co.cell_datum.present?
            elsif co.cell_datum.present?
              co.cell_datum.update!(data: binary_data)
            else
              co.cell_datum.create!(data: binary_data)
            end
          end
        end
      end
    end
  rescue StandardError => _e
    retry_count += 1
    if retry_count > 2
      $retry_ids << range.first
    else
      compare_output(range, retry_count)
    end
  end
end

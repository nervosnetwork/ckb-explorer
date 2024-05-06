namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:check_output_capacity[0, 10000]"
  task :check_output_capacity, %i[start_block end_block] => :environment do |_, args|
    (args[:start_block].to_i..args[:end_block].to_i).to_a.each do |number|
      check_capacity(number, 0)
    end; nil

    puts "done"

    def check_capacity(number, retry_count)
      target_block = CkbSync::Api.instance.get_block_by_number(number)
      txs = target_block.transactions
      txs.each do |tx|
        tx.inputs.each do |input|
          unless input.previous_output.tx_hash == "0x0000000000000000000000000000000000000000000000000000000000000000"
            result = CellOutput.where(tx_hash: input.previous_output.tx_hash, cell_index: input.previous_output.index, status: :dead).exists?
            unless result
              puts "#{input.previous_output.tx_hash}-#{input.index}"
            end
          end
        end
        tx.outputs.each_with_index do |output, index|
          db_output = CellOutput.find_by(tx_hash: tx.hash, cell_index: index)
          if db_output.capacity != output.capacity
            puts "#{tx.hash}-#{index}"
          end
        end
      end; nil
    rescue StandardError => _e
      retry_count += 1
      if retry_count > 2
        puts number
      else
        check_capacity(number, retry_count)
      end
    end
  end
end

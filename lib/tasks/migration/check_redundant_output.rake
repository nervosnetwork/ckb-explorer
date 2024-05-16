namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:check_redundant_output[0,10000]"
  task :check_redundant_output, %i[start_block end_block] => :environment do |_, args|
    error_ids = Set.new
    retry_ids = Set.new
    (args[:start_block].to_i..args[:end_block].to_i).to_a.each do |number|
      check_output(number, 0, error_ids, retry_ids)
    end; nil

    puts "error IDS:"
    puts error_ids
    puts "retry IDS:"
    puts retry_ids.join(",")
    puts "done"
  end

  def check_output(number, retry_count, error_ids, retry_ids)
    target_block = CkbSync::Api.instance.get_block_by_number(number)
    txs = target_block.transactions
    txs.each do |tx|
      if CellOutput.where(tx_hash: tx.hash).count != tx.outputs.count
        rpc_results = []
        tx.outputs.each_with_index do |_output, index|
          rpc_results << ["#{tx.hash}", index]
        end
        db_results = CellOutput.where(tx_hash: tx.hash).pluck(:tx_hash, :cell_index)
        different = rpc_results - db_results | db_results - rpc_results
        different.each do |d|
          error_ids << d.join("-")
        end
      end
    end; nil
  rescue StandardError => _e
    retry_count += 1
    if retry_count > 2
      retry_ids << number
    else
      check_output(number, retry_count, error_ids, retry_ids)
    end
  end
end

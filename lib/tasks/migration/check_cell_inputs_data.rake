namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:check_cell_inputs_data[0,10000]"
  task :check_cell_inputs_data, %i[start_block end_block] => :environment do |_, args|
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")
    error_ids = []
    (args[:start_block].to_i..args[:end_block].to_i).to_a.each_slice(1000).each do |range|
      puts range[0]
      CkbTransaction.tx_committed.where(block_number: range[0]..range[-1]).where(is_cellbase: false).each do |tx|
        if tx.cell_inputs.count != tx.inputs.count
          error_ids << tx.id
        end
      end
    end

    puts "error IDS:"
    puts error_ids.join(",")
    puts "=============="
    puts "done"
  end
end

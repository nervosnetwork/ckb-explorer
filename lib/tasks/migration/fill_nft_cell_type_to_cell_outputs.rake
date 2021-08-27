namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake 'migration:fill_nft_cell_type_to_cell_outputs[ckb]'"
  task :fill_nft_cell_type_to_cell_outputs, [:chain] => :environment do |_, args|
    if args[:chain].blank?
	    puts "missing chain type"
	    next
    end

    chain = args[:chain]
    puts "chain: #{chain}"

    cell_output_ids = []
    total_count = TypeScript.where(code_hash: [CkbSync::Api.instance.issuer_script_code_hash, CkbSync::Api.instance.token_class_script_code_hash, CkbSync::Api.instance.token_script_code_hash]).count
    progress_bar = ProgressBar.create({ total: total_count, format: "%e %B %p%% %c/%C" })
    puts "total_count: #{total_count}"

    TypeScript.where(code_hash: [CkbSync::Api.instance.issuer_script_code_hash, CkbSync::Api.instance.token_class_script_code_hash, CkbSync::Api.instance.token_script_code_hash]).find_each do |ts|
      if chain == "ckb"
        nft_cell = ts.cell_output
        cell_output_ids << nft_cell.id
        nft_cell.update(cell_type: CkbUtils.cell_type(ts, "0x"))
        progress_bar.increment
      else
        nft_cells = CellOutput.where(type_script_id: ts.id)
        nft_cells.each do |nft_cell|
          cell_output_ids << nft_cell.id
          nft_cell.update(cell_type: CkbUtils.cell_type(ts, "0x"))
          progress_bar.increment
        end
      end
    end

    tx_ids = Set.new
    puts "collect tx_ids..."
    CellOutput.where(id: cell_output_ids).each do |output|
      tx_ids << output.generated_by_id
      tx_ids << output.consumed_by_id
    end

    puts "flush display info cache"
    # flush display info cache
    puts "tx_ids: #{tx_ids}"
    TxDisplayInfoGeneratorWorker.new.perform(tx_ids.to_a.compact)

    puts "done"
  end
end

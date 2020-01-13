namespace :migration do
  task update_block_live_cell_changes: :environment do
    progress_bar = ProgressBar.create({ total: Block.count, format: "%e %B %p%% %c/%C" })
    columns = [:id, :live_cell_changes]
    Block.order(:id).find_in_batches(batch_size: 4000) do |blocks|
      values =
        blocks.map do |block|
          progress_bar.increment
          live_cell_changes = block.ckb_transactions.sum(&:live_cell_changes)
          [block.id, live_cell_changes]
        end

      Block.import columns, values, validate:false, on_duplicate_key_update: [:live_cell_changes]
    end

    puts "done"
  end
end

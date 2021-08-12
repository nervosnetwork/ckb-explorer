namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_consumed_block_timestamp_to_cell_output"
  task fill_consumed_block_timestamp_to_cell_output: :environment do
    cell_outputs = CellOutput.dead.where(consumed_block_timestamp: nil)
    progress_bar = ProgressBar.create({
      total: cell_outputs.count,
      format: "%e %B %p%% %c/%C"
    })
    cell_outputs.find_in_batches do |cell_outputs|
      attributes = cell_outputs.map do |cell_output|
        progress_bar.increment
        { id: cell_output.id, consumed_block_timestamp: cell_output.ckb_transaction.block_timestamp, created_at: cell_output.created_at, updated_at: Time.current }
      end
      CellOutput.upsert_all(attributes) if attributes.present?
    end

    puts "done"
  end
end

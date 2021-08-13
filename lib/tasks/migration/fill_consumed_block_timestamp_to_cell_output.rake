namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_consumed_block_timestamp_to_cell_output"
  task fill_consumed_block_timestamp_to_cell_output: :environment do
    i = 0
    CellOutput.where(consumed_block_timestamp: nil).select(:id).find_in_batches(batch_size: 10) do |cell_outputs|
      puts "index: #{i}"
      i += 1
      CellOutput.where(id: cell_outputs.pluck(:id)).update_all(consumed_block_timestamp: 0)
    end
    cell_outputs = CellOutput.dead.where(consumed_block_timestamp: 0)
    progress_bar = ProgressBar.create({
      total: cell_outputs.count,
      format: "%e %B %p%% %c/%C"
    })
    cell_outputs.find_in_batches(batch_size: 100) do |cell_outputs|
      attributes = cell_outputs.map do |cell_output|
        progress_bar.increment
        { id: cell_output.id, consumed_block_timestamp: cell_output.consumed_by.block_timestamp, created_at: cell_output.created_at, updated_at: Time.current }
      end
      CellOutput.upsert_all(attributes) if attributes.present?
    end

    puts "done"
  end
end

namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_dao_to_cell_outputs"
  task fill_dao_to_cell_outputs: :environment do
    progress_bar = ProgressBar.create(total: CellOutput.count, format: "%e %B %p%% %c/%C")
    CellOutput.find_in_batches do |cell_outputs|
      values = cell_outputs.map do |cell_output|
        progress_bar.increment
        { id: cell_output.id, dao: cell_output.block.dao, created_at: cell_output.created_at, updated_at: cell_output.updated_at }
      end

      CellOutput.upsert_all(values)
    end

    puts "done"
  end
end

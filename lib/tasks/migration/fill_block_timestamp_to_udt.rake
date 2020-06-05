namespace :migration do
  task fill_block_timestamp_to_udt: :environment do
    udts = Udt.all
    progress_bar = ProgressBar.create({
      total: udts.count,
      format: "%e %B %p%% %c/%C"
    })

    values =
      udts.map do |udt|
        progress_bar.increment
        cell_output = CellOutput.find_by(type_hash: udt.type_hash)
        { id: udt.id, block_timestamp: cell_output.block_timestamp, created_at: udt.created_at, updated_at: Time.current }
      end

    Udt.upsert_all(values)

    puts "done"
  end
end

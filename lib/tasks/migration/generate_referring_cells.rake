namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:generate_referring_cells"
  task generate_referring_cells: :environment do
    live_cells = CellOutput.live.left_joins(:referring_cell).where(referring_cells: { id: nil })
    progress_bar = ProgressBar.create({ total: live_cells.count, format: "%e %B %p%% %c/%C" })

    live_cells.find_in_batches do |outputs|
      outputs.each do |output|
        progress_bar.increment

        contract = output.lock_script&.contract
        contract ||= output.type_script&.contract

        next unless contract

        ReferringCell.create_or_find_by(
          cell_output_id: output.id,
          ckb_transaction_id: output.ckb_transaction_id,
          contract_id: contract.id
        )
      end
    end

    puts "done"
  end
end

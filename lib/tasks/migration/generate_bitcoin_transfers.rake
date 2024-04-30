namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:generate_bitcoin_transfers"
  task generate_bitcoin_transfers: :environment do
    block_numbers = []
    binary_hashes = CkbUtils.hexes_to_bins_sql(
      [CkbSync::Api.instance.rgbpp_code_hash, CkbSync::Api.instance.btc_time_code_hash],
    )

    LockScript.where("code_hash IN (#{binary_hashes})").find_in_batches(batch_size: 50) do |lock_scripts|
      CellOutput.where(lock_script_id: lock_scripts.map(&:id)).find_each do |cell_output|
        ckb_transaction = cell_output.ckb_transaction
        # next if BitcoinTransfer.exists?(ckb_transaction:, cell_output:)

        block_number = ckb_transaction.block_number
        next if block_numbers.include?(block_number)

        block_numbers << block_number
      end
    end

    progress_bar = ProgressBar.create(
      {
        total: block_numbers.length,
        format: "%e %B %p%% %c/%C",
      },
    )
    block_numbers.sort.each do |block_number|
      begin
        BitcoinTransactionDetectWorker.new.perform(block_number)
      rescue StandardError => e
        Rails.logger.error "Failed to process block number #{block_number}: #{e}"
      end

      progress_bar.increment
    end

    puts "done"
  end
end

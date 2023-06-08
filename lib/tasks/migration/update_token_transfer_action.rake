namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:update_token_transfer_action"
  task update_token_transfer_action: :environment do
    total_count = TokenCollection.where(standard: "cota").count
    progress_bar = ProgressBar.create({ total: total_count, format: "%e %B %p%% %c/%C" })

    TokenCollection.where(standard: "cota").find_each do |collection|
      collection.transfers.each do |transfer|
        block_number = transfer.ckb_transaction.block_number
        data = CotaAggregator.instance.get_transactions_by_block_number(block_number)
        data["transactions"].each do |t|
          action =
            case t["tx_type"]
              when "mint"
                "mint"
              when "transfer"
                "normal"
            end
          token_id = t["token_index"].hex

          next if token_id != transfer.item.token_id
          next if action == transfer.action

          transfer.update(action: action)
        end
      end

      progress_bar.increment
    rescue => e
      puts e
    end
  end
end

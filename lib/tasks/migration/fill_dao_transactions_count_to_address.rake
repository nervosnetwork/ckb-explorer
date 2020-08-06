namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_dao_transactions_count_to_address"
  task fill_dao_transactions_count_to_address: :environment do
    progress_bar = ProgressBar.create({
      total: Address.count,
      format: "%e %B %p%% %c/%C"
    })

    values =
      Address.all.map do |address|
      progress_bar.increment
      dao_transactions_count = address.ckb_dao_transactions.count

      { id: udt.id, dao_transactions_count: dao_transactions_count, created_at: udt.created_at, updated_at: Time.current }
    end

    Address.upsert_all(values) if values.present?

    puts "done"
  end
end

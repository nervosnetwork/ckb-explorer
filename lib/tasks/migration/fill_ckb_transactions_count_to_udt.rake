namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_ckb_transactions_count_to_udt"
  task fill_ckb_transactions_count_to_udt: :environment do
    progress_bar = ProgressBar.create({
      total: Udt.count,
      format: "%e %B %p%% %c/%C"
    })

    values =
        Udt.all.map do |udt|
        progress_bar.increment
        ckb_transactions_count = udt.ckb_transactions.count

        { id: udt.id, ckb_transactions_count: ckb_transactions_count, created_at: udt.created_at, updated_at: Time.current }
      end

    Udt.upsert_all(values) if values.present?

    puts "done"
  end
end

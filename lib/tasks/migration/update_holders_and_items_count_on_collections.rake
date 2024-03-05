namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:update_holders_and_items_count_on_collections"
  task update_holders_and_items_count_on_collections: :environment do
    total_count = TokenCollection.count
    progress_bar = ProgressBar.create({ total: total_count, format: "%e %B %p%% %c/%C" })

    TokenCollection.find_each do |collection|
      items_count = collection.items.normal.count
      TokenCollection.update_counters(collection.id, items_count:)
      holders_count = collection.items.normal.distinct.count(:owner_id)
      collection.update_column(:holders_count, holders_count)
      progress_bar.increment
    end
  end
end

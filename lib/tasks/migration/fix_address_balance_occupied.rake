namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fix_address_balance_occupied"
  task fix_address_balance_occupied: :environment do
    pr_merged_datetime = DateTime.new(2022,7,23,0,0,0)
    addresses = Address.where("updated_at > ?", pr_merged_datetime).order(id: :asc)
    addresses.find_each do |address|
      puts "Address ID: #{address.id}"

      occupied = address.cell_outputs.live.occupied.sum(:capacity)
      address.update(balance_occupied: occupied)
    end
    puts "done"
  end
end

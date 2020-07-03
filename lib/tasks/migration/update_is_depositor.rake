namespace :migration do
  task update_is_depositor: :environment do
    Address.where("dao_deposit > 0").update(is_depositor: true)

    puts "done"
  end
end

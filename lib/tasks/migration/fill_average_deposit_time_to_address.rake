namespace :migration do
  task fill_average_deposit_time_to_address: :environment do
    addresses = Address.where("dao_deposit > 0").where(average_deposit_time: nil)
    progress_bar = ProgressBar.create({
      total: addresses.count,
      format: "%e %B %p%% %c/%C"
    })

    values =
      addresses.map do |address|
        progress_bar.increment
        generator = AddressAverageDepositTimeGenerator.new
        [address.id, generator.send(:cal_average_deposit_time, address)]
      end

    columns = [:id, :average_deposit_time]
    Address.import columns, values, on_duplicate_key_update: [:average_deposit_time]

    puts "done"
  end
end

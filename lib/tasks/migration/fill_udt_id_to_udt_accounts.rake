namespace :migration do
  task fill_udt_id_to_udt_accounts: :environment do
    Udt.all.each do |udt|
      UdtAccount.where(type_hash: udt.type_hash).update_all(udt_id: udt.id)
    end

    puts "done"
  end
end

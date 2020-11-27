namespace :migration do
  task update_short_acp_address: :environment do
	  address_ids = LockScript.where(code_hash: "0xd369597ff47f29fbc0d47d2e3775370d1250b85140c670e4718af712983a2354").pluck(:address_id).uniq
	  addresses = Address.where(id: address_ids)
    progress_bar = ProgressBar.create({
      total: addresses.count,
      format: "%e %B %p%% %c/%C"
    })

	  addresses.each do |address|
		  s = address.lock_script
		  lock = CKB::Types::Script.new(s.to_node_lock)
		  short_acp_address = CKB::Address.new(lock).generate
		  puts "full address: #{address.address_hash}, short acp address: #{short_acp_address}"
		  address.update(address_hash: short_acp_address)

      progress_bar.increment
	  end

    puts "done"
  end
end

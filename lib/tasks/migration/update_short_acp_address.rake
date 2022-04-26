namespace :migration do
  task :update_short_acp_address, [:mode] => :environment do |_, args|
	  mode = args[:mode].downcase
	  if mode == "testnet"
		  code_hash = "0x3419a1c09eb2567f6552ee7a8ecffd64155cffe0f1796e6e61ec088d740c1356"
	  else
		  code_hash = "0xd369597ff47f29fbc0d47d2e3775370d1250b85140c670e4718af712983a2354"
	  end
	  puts "mode: #{mode}"
	  address_ids = LockScript.where(code_hash: code_hash).pluck(:address_id).uniq
	  addresses = Address.where(id: address_ids)
    progress_bar = ProgressBar.create({
      total: addresses.count,
      format: "%e %B %p%% %c/%C"
    })

	  addresses.each do |address|
		  s = address.lock_script
		  lock = CKB::Types::Script.new(**s.to_node_lock)
		  short_acp_address = CKB::Address.new(lock, mode: mode).generate
		  puts "full address: #{address.address_hash}, short acp address: #{short_acp_address}"
		  address.update(address_hash: short_acp_address)

      progress_bar.increment
	  end

    puts "done"
  end
end

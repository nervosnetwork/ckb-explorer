namespace :migration do
  task update_addresses_info: :environment do
    local_tip_block = Block.recent.first
	  Block.where("number > ?", 1435304).select(:id, :number, :address_ids).find_each do |block|
		  addr_attrs = []
		  Address.where(id: block.address_ids).select(:id, :created_at).each do |addr|
        addr_attrs << { id: addr.id, balance: addr.cell_outputs.live.sum(:capacity),ckb_transactions_count: addr.custom_ckb_transactions.count, live_cells_count: addr.cell_outputs.live.count,
                        dao_transactions_count: addr.ckb_dao_transactions.count, created_at: addr.created_at, updated_at: Time.current }
		  end
		  Address.upsert_all(addr_attrs)
		  puts "#{local_tip_block.number - block.number} blocks left"
	  end

    puts "done"
  end
end

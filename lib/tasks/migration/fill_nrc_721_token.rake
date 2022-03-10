namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:update_nrc_721_token_info[token_code_hash]"
  task :update_nrc_721_token_info, [:token_code_hash]  => :environment do |_, args|
    udts = UDT.where(code_hash: args[:token_code_hash], hash_type: "type")
    udts.each do |udt|
      factory_cell = CkbUtils.parse_nrc_721_args(udt.args) 
      nrc_721_factory_cell_type = TypeScript.where(code_hash: factory_cell.code_hash, hash_type: factory_cell.hash_type, args: factory_cell.args).first
      parsed_factory_data = CkbUtils.parse_nrc_721_factory_data(nrc_721_factory_cell.data)
      udt.update(full_name: parsed_factory_data.name, symbol: parsed_factory_data.symbol, icon_file: "#{parsed_factory_data.base_token_uri}/#{factory_cell.token_id}")
      UdtAccount.where(udt_id: udt_id).update_all(full_name: parsed_factory_data.name, symbol: parsed_factory_data.symbol, icon_file: "#{parsed_factory_data.base_token_uri}/#{factory_cell.token_id}")
    end
  end

  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_old_nrc_721_token[0x7d77d51ba9a1123939de4ee06a86416f8edd747591aa3768426b3b199c2b4bd5]"
  task :fill_old_nrc_721_token, [:block_hash] => :environment do |_, args|
    start_block = Block.find_by_block_hash(args[:block_hash])
    CellOutput.where("block_id >= #{start_block.id}").where("data like '#{Settings.nrc_721_factory_output_data_header}%'").where.not(cell_type: "nrc_721_factory").update_all(cell_type: "nrc_721_factory")
    nrc_tokens = CellOutput.where("block_id >= #{start_block.id}").where("data like '#{Settings.nrc_721_token_output_data_header}%'").where.not(cell_type: "nrc_721_token").order(id: :asc)
    nrc_tokens.each do |output|
      output.update(cell_type: "nrc_721_token")
      factory_cell = CkbUtils.parse_nrc_721_args(output.type_script.args)
      type_hash = output.type_script.script_hash

      udts_attributes = []
      nrc_721_factory_cell_type = TypeScript.where(code_hash: factory_cell.code_hash, hash_type: factory_cell.hash_type, args: factory_cell.args).first
      if nrc_721_factory_cell_type.present?
        nrc_721_factory_cell = nrc_721_factory_cell_type.cell_outputs.nrc_721_factory.last
        parsed_factory_data = CkbUtils.parse_nrc_721_factory_data(nrc_721_factory_cell.data)
        nft_token_attr[:full_name] = parsed_factory_data.name
        nft_token_attr[:symbol] = parsed_factory_data.symbol
        nft_token_attr[:icon_file] = "#{parsed_factory_data.base_token_uri}/#{factory_cell.token_id}"
        nft_token_attr[:published] = true
      end
      udts_attributes << {
        type_hash: type_hash, udt_type: "nrc_721_token", block_timestamp: output.block_timestamp, args: output.type_script.args,
        code_hash: output.type_script.code_hash, hash_type: output.type_script.hash_type }.merge(nft_token_attr)
    end
    Udt.insert_all(udts_attributes.map! { |attr| attr.merge!(created_at: Time.current, updated_at: Time.current) }) if udts_attributes.present?

    # update udt account
    nrc_tokens.live.select(:id, :address_id, :type_hash, :cell_type, :type_script_id).each do |udt_output|
      address = Address.find(udt_output.address_id)
      udt_account = address.udt_accounts.where(type_hash: udt_output.type_hash, udt_type: "nrc_721_token").select(:id, :created_at).first
      amount = 0
      nft_token_id = CkbUtils.parse_nrc_721_args(udt_output.type_script.args).token_id
      udt = Udt.where(type_hash: udt_output.type_hash, udt_type: "nrc_721_token").select(:id, :udt_type, :full_name, :symbol, :decimal, :published, :code_hash, :type_hash, :created_at).take!
      if udt_account.blank?
        new_udt_accounts_attributes << {
          address_id: udt_output.address_id, udt_type: udt.udt_type, full_name: udt.full_name, symbol: udt.symbol, decimal: udt.decimal,
          published: udt.published, code_hash: udt.code_hash, type_hash: udt.type_hash, amount: amount, udt_id: udt.id, nft_token_id: nft_token_id }
      end
    end
    UdtAccount.insert_all!(new_udt_accounts_attributes.map! { |attr| attr.merge!(created_at: Time.current, updated_at: Time.current) }) if new_udt_accounts_attributes.present?

    puts "done"
  end
end

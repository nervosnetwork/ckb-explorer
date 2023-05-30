namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:update_nrc_721_token_info[factory_code_hash, factory_hash_type, factory_args]"
  task :update_nrc_721_token_info, [:factory_code_hash, :factory_hash_type, :factory_args] => :environment do |_, args|
    factory_cell = NrcFactoryCell.find_by(code_hash: args[:factory_code_hash], hash_type: args[:factory_hash_type],
                                          args: args[:factory_args])

    if factory_cell.nil?
      puts "No Factory Cell Found!"
      return
    end

    nrc_721_factory_cell_type = TypeScript.where(code_hash: factory_cell.code_hash, hash_type: factory_cell.hash_type,
                                                 args: factory_cell.args).last
    factory_data = CellOutput.where(type_script_id: nrc_721_factory_cell_type.id,
                                    cell_type: "nrc_721_factory").last.data
    parsed_factory_data = CkbUtils.parse_nrc_721_factory_data(factory_data)
    factory_cell.update(verified: true, name: parsed_factory_data.name, symbol: parsed_factory_data.symbol,
                        base_token_uri: parsed_factory_data.base_token_uri, extra_data: parsed_factory_data.extra_data)
    udts = Udt.where(nrc_factory_cell_id: factory_cell.id)
    udts.each do |udt|
      udt_account = UdtAccount.where(udt_id: udt.id, udt_type: "nrc_721_token").first
      udt_account.update(full_name: parsed_factory_data.name, symbol: parsed_factory_data.symbol)
      udt.update(full_name: parsed_factory_data.name, symbol: parsed_factory_data.symbol,
                 icon_file: "#{parsed_factory_data.base_token_uri}/#{udt_account.nft_token_id}")

      tx_ids = udt.ckb_transactions.pluck(:id)
      tx_ids.each do |tx_id|
        Rails.cache.delete("normal_tx_display_outputs_previews_false_#{tx_id}")
        Rails.cache.delete("normal_tx_display_outputs_previews_true_#{tx_id}")
        Rails.cache.delete("normal_tx_display_inputs_previews_false_#{tx_id}")
        Rails.cache.delete("normal_tx_display_inputs_previews_true_#{tx_id}")
        Rails.cache.delete("TxDisplayInfo/#{tx_id}")
      end
      TxDisplayInfoGeneratorWorker.new.perform(tx_ids)
      # update udt transaction page cache
      ckb_transactions = udt.ckb_transactions.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp,
                                                     :is_cellbase, :updated_at).recent.page(1).per(CkbTransaction.default_per_page)
      Rails.cache.delete(ckb_transactions.cache_key)

      # update addresses transaction page cache
      CkbTransaction.where(id: tx_ids).find_each do |ckb_tx|
        Address.where(id: ckb_tx.contained_address_ids).find_each do |address|
          ckb_transactions = address.custom_ckb_transactions.select(:id, :tx_hash, :block_id, :block_number,
                                                                    :block_timestamp, :is_cellbase, :updated_at).recent.page(1).per(CkbTransaction.default_per_page)
          Rails.cache.delete("#{ckb_transactions.cache_key}/#{address.query_address}")
        end
      end
    end
  end

  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_old_nrc_721_token[0x7d77d51ba9a1123939de4ee06a86416f8edd747591aa3768426b3b199c2b4bd5]"
  task :fill_old_nrc_721_token, [:block_hash] => :environment do |_, args|
    start_block = Block.find_by_block_hash(args[:block_hash])
    CellOutput.where("block_id >= #{start_block.id}").where("data like '#{Settings.nrc_721_factory_output_data_header}%'").where.not(cell_type: "nrc_721_factory").update_all(cell_type: "nrc_721_factory")
    CellOutput.where("block_id >= #{start_block.id}").where("data like '#{Settings.nrc_721_token_output_data_header}%'").where.not(cell_type: "nrc_721_token").order(id: :asc).update_all(cell_type: "nrc_721_token")
    nrc_tokens = CellOutput.where("block_id >= #{start_block.id}").where("data like '#{Settings.nrc_721_token_output_data_header}%'").where(cell_type: "nrc_721_token").order(id: :asc).
      udts_attributes = []
    nrc_tokens.each do |output|
      factory_cell = CkbUtils.parse_nrc_721_args(output.type_script.args)
      type_hash = output.type_script.script_hash
      nrc_721_factory_cell_type = TypeScript.where(code_hash: factory_cell.code_hash,
                                                   hash_type: factory_cell.hash_type, args: factory_cell.args).first
      factory_data = CellOutput.where(type_script_id: nrc_721_factory_cell_type.id,
                                      cell_type: "nrc_721_factory").last.data
      nft_token_attr = {}
      if nrc_721_factory_cell_type.present?
        parsed_factory_data = CkbUtils.parse_nrc_721_factory_data(factory_data)
        nrc_721_factory_cell = NrcFactoryCell.find_or_create_by(code_hash: factory_cell.code_hash,
                                                                hash_type: factory_cell.hash_type, args: factory_cell.args)
        nrc_721_factory_cell.update(verified: true, name: parsed_factory_data.name, symbol: parsed_factory_data.symbol,
                                    base_token_uri: parsed_factory_data.base_token_uri, extra_data: parsed_factory_data.extra_data)
        nft_token_attr[:full_name] = parsed_factory_data.name
        nft_token_attr[:symbol] = parsed_factory_data.symbol
        nft_token_attr[:icon_file] = "#{parsed_factory_data.base_token_uri}/#{factory_cell.token_id}"
        nft_token_attr[:nrc_factory_cell_id] = nrc_721_factory_cell.id
        nft_token_attr[:published] = true
      end
      udts_attributes << {
        type_hash: type_hash, udt_type: "nrc_721_token", block_timestamp: output.block_timestamp, args: output.type_script.args,
        code_hash: output.type_script.code_hash, hash_type: output.type_script.hash_type }.merge(nft_token_attr)
    end
    if udts_attributes.present?
      Udt.insert_all(udts_attributes.map! do |attr|
                       attr.merge!(created_at: Time.current, updated_at: Time.current)
                     end)
    end

    # update udt account
    new_udt_accounts_attributes = []
    nrc_tokens.live.select(:id, :address_id, :type_hash, :cell_type, :type_script_id).each do |udt_output|
      address = Address.find(udt_output.address_id)
      udt_account = address.udt_accounts.where(type_hash: udt_output.type_hash, udt_type: "nrc_721_token").select(:id,
                                                                                                                  :created_at).first
      amount = 0
      nft_token_id = CkbUtils.parse_nrc_721_args(udt_output.type_script.args).token_id
      udt = Udt.where(type_hash: udt_output.type_hash, udt_type: "nrc_721_token").select(:id, :udt_type, :full_name,
                                                                                         :symbol, :decimal, :published, :code_hash, :type_hash, :created_at).take!
      if udt_account.blank?
        new_udt_accounts_attributes << {
          address_id: udt_output.address_id, udt_type: udt.udt_type, full_name: udt.full_name, symbol: udt.symbol, decimal: udt.decimal,
          published: udt.published, code_hash: udt.code_hash, type_hash: udt.type_hash, amount: amount, udt_id: udt.id, nft_token_id: nft_token_id }
      end
    end
    if new_udt_accounts_attributes.present?
      UdtAccount.insert_all(new_udt_accounts_attributes.map! do |attr|
                              attr.merge!(created_at: Time.current, updated_at: Time.current)
                            end)
    end

    puts "done"
  end
end

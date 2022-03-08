namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_nrc_721_token"
  task fill_nrc_721_token: :environment do
    outputs = CellOutput.where(tx_hash: "0x09d9bbd0d3745fad1334b9294456a1a70e66730195f46ab3c5ab120dd8ff3dc2")
    nrc_721_tokens = outputs[0..4]
    nrc_721_factory = outputs[5]
    udts_attributes = []

    # create udt
    nrc_721_tokens.each do |output|
      type_hash = output.type_script.script_hash
      nft_token_attr = { full_name: nil, icon_file: nil, published: false, symbol: nil }
      factory_cell = CkbUtils.parse_nrc_721_args(output.type_script.args)
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
        type_hash: type_hash, udt_type: "m_nft_token", block_timestamp: output.block_timestamp, args: output.type_script.args,
        code_hash: output.type_script.code_hash, hash_type: output.type_script.hash_type }.merge(nft_token_attr)

      output.update(cell_type: "nrc_721_token")
    end
    Udt.insert_all!(udts_attributes.map! { |attr| attr.merge!(created_at: Time.current, updated_at: Time.current) }) if udts_attributes.present?

    # update udt account
    local_block = Block.find_by_number(4631213)
    new_udt_accounts_attributes = Set.new
    local_block.cell_outputs.where(cell_type: %w(nrc_721_token)).select(:id, :address_id, :type_hash, :cell_type).find_each do |udt_output|
      address = Address.find(udt_output.address_id)
      udt_type = udt_type(udt_output.cell_type)
      udt_account = address.udt_accounts.where(type_hash: udt_output.type_hash, udt_type: udt_type).select(:id, :created_at).first
      amount = udt_account_amount(udt_type, udt_output.type_hash, address)
      nft_token_id =
        udt_type == "nrc_721_token" ?  CkbUtils.parse_nrc_721_args(udt_output.type_script.args).token_id : nil
      udt = Udt.where(type_hash: udt_output.type_hash, udt_type: udt_type).select(:id, :udt_type, :full_name, :symbol, :decimal, :published, :code_hash, :type_hash, :created_at).take!
      if udt_account.blank?
        new_udt_accounts_attributes << {
          address_id: udt_output.address_id, udt_type: udt.udt_type, full_name: udt.full_name, symbol: udt.symbol, decimal: udt.decimal,
          published: udt.published, code_hash: udt.code_hash, type_hash: udt.type_hash, amount: amount, udt_id: udt.id, nft_token_id: nft_token_id }
      end
    end
    UdtAccount.insert_all!(new_udt_accounts_attributes.map! { |attr| attr.merge!(created_at: Time.current, updated_at: Time.current) }) if new_udt_accounts_attributes.present?

    nrc_721_factory.update(cell_type: "nrc_721_factory")
    puts "done"
  end
end

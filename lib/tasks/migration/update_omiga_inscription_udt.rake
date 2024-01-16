namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:update_omiga_inscription_udt"
  task update_omiga_inscription_udt: :environment do
    info_ts_ids = TypeScript.where(code_hash: CkbSync::Api.instance.omiga_inscription_info_code_hash).pluck(:id)
    info_outputs = CellOutput.where(type_script_id: info_ts_ids)
    info_outputs.update_all(cell_type: "omiga_inscription_info")

    info_outputs.each do |output|
      info = CkbUtils.parse_omiga_inscription_info(output.data)
      # ignore old version data
      if output.data.slice(-2..-1).in?(["00", "01", "02"])
        OmigaInscriptionInfo.upsert(info.merge(output.type_script.to_node),
                                    unique_by: :udt_hash)
      end
    end

    xudt_ts_ids = TypeScript.where(code_hash: CkbSync::Api.instance.xudt_code_hash).pluck(:id)
    xudt_ts_ids.each do |tid|
      xudt_outputs = CellOutput.where(type_script_id: tid)
      xudt_outputs.each do |output|
        if OmigaInscriptionInfo.where(udt_hash: output.type_hash).exists?
          info = OmigaInscriptionInfo.find_by!(udt_hash: output.type_hash)
          output.update(cell_type: "omiga_inscription",
                        udt_amount: info.mint_limit)
          if info.udt_id.nil?
            nft_token_attr = {}
            nft_token_attr[:full_name] = info.name.presence
            nft_token_attr[:symbol] = info.symbol.presence
            nft_token_attr[:decimal] = info.decimal
            nft_token_attr[:published] = true
            udt = Udt.create_or_find_by!({
              type_hash: output.type_hash,
              udt_type: "omiga_inscription",
              block_timestamp: output.block.timestamp,
              args: output.type_script.args,
              code_hash: output.type_script.code_hash,
              hash_type: output.type_script.hash_type,
            }.merge(nft_token_attr))
            info.update!(udt_id: udt.id)
          end
        else
          output.update(cell_type: "xudt")
        end
      end
    end

    # udt_transaction
    Udt.where(udt_type: "omiga_inscription").each do |udt|
      outputs = CellOutput.omiga_inscription.where(type_hash: udt.type_hash).select(
        :address_id, :ckb_transaction_id
      ).distinct
      udt_transaction_attrs =
        outputs.map do |output|
          { udt_id: udt.id, ckb_transaction_id: output.ckb_transaction_id }
        end
      UdtTransaction.insert_all(udt_transaction_attrs)

      address_udt_transaction_attrs =
        outputs.map do |output|
          { address_id: output.address_id,
            ckb_transaction_id: output.ckb_transaction_id }
        end
      AddressUdtTransaction.insert_all(address_udt_transaction_attrs)
    end

    # udt_account
    Udt.where(udt_type: "omiga_inscription").each do |udt|
      # {address_id => udt_amount}
      results = CellOutput.live.omiga_inscription.where(type_hash: udt.type_hash).select(:address_id).group(:address_id).sum(:udt_amount)
      attrs =
        results.map do |address_id, udt_amount|
          {
            address_id:, udt_type: udt.udt_type, full_name: udt.full_name, symbol: udt.symbol, decimal: udt.decimal,
            published: udt.published, code_hash: udt.code_hash, type_hash: udt.type_hash, amount: udt_amount, udt_id: udt.id
          }
        end

      unless attrs.empty?
        UdtAccount.insert_all(attrs)
        udt.update(total_amount: results.sum do |_k, v|
                                   v
                                 end, addresses_count: results.length)
      end
    end

    puts "done"
  end
end

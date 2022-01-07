class UdtRegister
  include Rake::DSL

  def initialize
    namespace :migration do
      desc "Usage: RAILS_ENV=production bundle exec rake 'migration:register_udt[nil]'"
      # mode can be normal or forcebridge
      task :register_udt, [:mode, :args, :symbol, :full_name, :decimal, :description, :operator_website] => :environment do |_, args|
        if args[:mode] == "forcebridge"
          register_forcebridge_udt
        elsif args[:mode] == "url"
          register_udts_from_url
        else
          register_udt(args)
        end
      end
    end
  end

  private

    def register_udts_from_url
      assets = assets_from_url
      puts "assets_from_url_counts: #{assets.size}"

      non_exist_udt_infos = []
      assets.each do |asset|
        args = { args: asset[:sudtArgs], symbol: asset[:symbol], full_name: asset[:name], decimal: asset[:decimal], icon_file: asset[:logoURI] }
        puts args
        type_script = build_udt_type_script(args)
        udt = Udt.find_by(type_hash: type_script.compute_hash)
        if udt.blank?
          puts "udt not exist, args: #{args}"
          non_exist_udt_infos << asset
          next
        end
        register_udt(args)
      end
    end

    def assets_from_url
      uri = URI(ENV["ASSET_URL"])
      http = Net::HTTP::Persistent.new
      request = Net::HTTP::Get.new(uri)
      response = http.request(uri, request)
      parse_response(response)
    end

    def register_forcebridge_udt
      puts "forcebridge_asset_counts: #{forcebridge_assets.size}"
      non_exist_udt_infos = []
      forcebridge_assets.each do |asset|
        next if asset[:network] != "Ethereum"

        args = { args: asset[:info][:shadow][:ident], symbol: asset[:info][:symbol], full_name: asset[:info][:name], decimal: asset[:info][:decimals], icon_file: asset[:info][:logoURI] }
        puts args
        type_script = build_udt_type_script(args)
        udt = Udt.find_by(type_hash: type_script.compute_hash)
        if udt.blank?
          puts "udt not exist, args: #{args[:args]}"
          non_exist_udt_infos << asset[:info]
          next
        end
        register_udt(args)
      end
      puts "non exist udts count: #{non_exist_udt_infos.size}"
      puts "non exist udts: #{non_exist_udt_infos}"
    end

    def forcebridge_assets
      uri = URI(ENV["FORCE_BRIDGE_HOST"])
      http = Net::HTTP::Persistent.new
      request = Net::HTTP::Post.new(uri)
      request.body = { id: SecureRandom.uuid, jsonrpc: "2.0", method: "getAssetList", params: { asset: "all" } }.to_json
      request["Content-Type"] = "application/json"
      response = http.request(uri, request)
      parse_response(response)[:result]
    end

    def parse_response(response)
      if response.code == "200"
        JSON.parse(response.body, symbolize_names: true)
      else
        error_messages = { body: response.body, code: response.code }
        raise error_messages
      end
    end

    def register_udt(args)
      unless params_valid?(args)
        puts "params invalid must exists"
        return
      end

      ApplicationRecord.transaction do
        type_script = build_udt_type_script(args)
        issuer_address = Address.where(lock_hash: type_script.args).pick(:address_hash)
        udt = Udt.find_by(type_hash: type_script.compute_hash)
        if udt.blank?
          puts "udt not exist, args: #{args[:args]}"
          return
        end
        udt.update!(code_hash: type_script.code_hash, hash_type: type_script.hash_type, args: type_script.args, symbol: args[:symbol], full_name: args[:full_name], decimal: args[:decimal], description: args[:description], operator_website: args[:operator_website], icon_file: args[:icon_file], issuer_address: issuer_address)
        udt.update!(published: true) if args[:icon_file].present?
        UdtAccount.where(udt_id: udt.id).update(symbol: udt.symbol, full_name: udt.full_name, decimal: udt.decimal, published: udt.published)
        flush_caches(udt)
        puts "UDT type_hash: #{udt.type_hash}"
      end
    end

    def build_udt_type_script(args)
      code_hash = "0x5e7a36a77e68eecc013dfa2fe6a23f3b6c344b04005808694ae6dd45eea4cfd5"#CkbSync::Api.instance.mode == "mainnet" ? "0x5e7a36a77e68eecc013dfa2fe6a23f3b6c344b04005808694ae6dd45eea4cfd5" : "0xc5e5dcf215925f7ef4dfaf5f4b4f105bc321c02776d6e7d52a1db3fcd9d011a4"
      CKB::Types::Script.new(args: args[:args], code_hash: code_hash, hash_type: "type")
    end

    def flush_caches(udt)
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
      ckb_transactions = udt.ckb_transactions.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent.page(1).per(CkbTransaction.default_per_page)
      Rails.cache.delete(ckb_transactions.cache_key)

      # update addresses transaction page cache
      CkbTransaction.where(id: tx_ids).find_each do |ckb_tx|
        Address.where(id: ckb_tx.contained_address_ids).find_each do |address|
          ckb_transactions = address.custom_ckb_transactions.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent.page(1).per(CkbTransaction.default_per_page)
          $redis.del("#{ckb_transactions.cache_key}/#{address.query_address}")
        end
      end
    end

    def params_valid?(args)
      return false if args[:args].blank? || args[:symbol].blank? || args[:full_name].blank? || args[:decimal].blank?

      true
    end
end

UdtRegister.new

class UdtRelatedDataUpdater
  include Rake::DSL

  def initialize
    namespace :migration do
      desc "Usage: bundle exec rake 'migration:update_udt_related_data[true, true]'"
      task :update_udt_related_data, [:create_udt, :create_udt_accounts] => :environment do |_, args|
        create_udts if args[:create_udt].downcase == "true"
        if args[:create_udt_accounts].downcase == "true"
          udt_infos = CellOutput.udt.pluck(:type_hash, :address_id).uniq
          create_udt_accounts(udt_infos)
          update_udt_info(udt_infos)
        end
        update_related_tx_caches

        puts "done"
      end
    end
  end

  private

  def update_udt_info(udt_infos)
    type_hashes = udt_infos.map { |udt_info| udt_info[0] }.uniq
    columns = %i(type_hash total_amount addresses_count)
    amount_hashes = UdtAccount.where(type_hash: type_hashes).group(:type_hash).sum(:amount)
    addresses_count_hashes = UdtAccount.where(type_hash: type_hashes).group(:type_hash).count(:address_id)
    import_values =
      type_hashes.map do |type_hash|
        [type_hash, amount_hashes[type_hash], addresses_count_hashes[type_hash]]
      end

    Udt.import columns, import_values, validate: false, on_duplicate_key_update: { conflict_target: [:type_hash], columns: [:total_amount, :addresses_count] }

    puts "udt info updated"
  end

  def create_udt_accounts(udt_infos)
    udt_accounts =
      udt_infos.map do |info|
        address = Address.find(info[1])
        udt_live_cell_data = address.cell_outputs.live.udt.where(type_hash: info[0]).pluck(:data)
        amount = udt_live_cell_data.map { |data| CkbUtils.parse_udt_cell_data(data) }.sum
        udt = Udt.find_or_create_by!(type_hash: info[0], code_hash: ENV["SUDT_CELL_TYPE_HASH"], udt_type: "sudt")
        { udt_id: udt.id, udt_type: Udt.udt_types[udt.udt_type], full_name: udt.full_name, symbol: udt.symbol, decimal: udt.decimal, published: udt.published, code_hash: udt.code_hash, type_hash: udt.type_hash, amount: amount, address_id: address.id, created_at: Time.now, updated_at: Time.now }
      end

    UdtAccount.upsert_all(udt_accounts, unique_by: :index_udt_accounts_on_type_hash_and_address_id)
    puts "udt accounts created"
  end

  def create_udts
    TypeScript.where(code_hash: ENV["SUDT_CELL_TYPE_HASH"]).each do |type_script|
      node_type = CKB::Types::Script.new(type_script.to_node_type)
      type_script.cell_output.update(cell_type: "udt")
      Udt.find_or_create_by!(args: type_script.args, hash_type: type_script.hash_type, type_hash: node_type.compute_hash, code_hash: ENV["SUDT_CELL_TYPE_HASH"], udt_type: "sudt")
    end

    puts "udts created"
  end


  def update_related_tx_caches
    type_scripts = TypeScript.where(code_hash: ENV["SUDT_CELL_TYPE_HASH"])
    type_hashes = type_scripts.map {|type_script| CKB::Types::Script.new(type_script.to_node_type).compute_hash }.uniq
    tx_ids = CellOutput.where(type_hash: type_hashes).pluck(:ckb_transaction_id)
    tx_ids.each do |tx_id|
      Rails.cache.delete("normal_tx_display_outputs_previews_false_#{tx_id}")
      Rails.cache.delete("normal_tx_display_outputs_previews_true_#{tx_id}")
      Rails.cache.delete("normal_tx_display_inputs_previews_false_#{tx_id}")
      Rails.cache.delete("normal_tx_display_inputs_previews_true_#{tx_id}")
    end
  end
end

UdtRelatedDataUpdater.new

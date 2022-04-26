class UdtRelatedDataUpdater
  include Rake::DSL

  def initialize
    namespace :migration do
      desc "Usage: bundle exec rake 'migration:update_udt_related_data[true, 0xc5e5dcf215925f7ef4dfaf5f4b4f105bc321c02776d6e7d52a1db3fcd9d011a4]'"
      task :update_udt_related_data, [:create_udt_accounts, :code_hash] => :environment do |_, args|
        update_udt_cells_info(args[:code_hash])
        if args[:create_udt_accounts].downcase == "true"
          type_hashes = TypeScript.where(code_hash: args[:code_hash]).map do |script|
            node_type = CKB::Types::Script.new(**script.to_node_type)
            node_type.compute_hash
          end
          udt_infos = CellOutput.udt.where(type_hash: type_hashes).pluck(:type_hash, :address_id).uniq
          create_udt_accounts(udt_infos)
          update_udt_info(udt_infos)
        end
        update_related_txs(args[:code_hash])

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
        udt = Udt.find_or_create_by!(type_hash: info[0], udt_type: "sudt")
        { udt_id: udt.id, udt_type: Udt.udt_types[udt.udt_type], full_name: udt.full_name, symbol: udt.symbol, decimal: udt.decimal, published: udt.published, code_hash: udt.code_hash, type_hash: udt.type_hash, amount: amount, address_id: address.id, created_at: Time.now, updated_at: Time.now }
      end

    UdtAccount.upsert_all(udt_accounts, unique_by: :index_udt_accounts_on_type_hash_and_address_id)
    puts "udt accounts created"
  end

  def update_udt_cells_info(code_hash)
    TypeScript.where(code_hash: code_hash).each do |type_script|
      node_type = CKB::Types::Script.new(**type_script.to_node_type)
      output = type_script.cell_output
      output.update(cell_type: "udt", type_hash: node_type.compute_hash, udt_amount: CkbUtils.parse_udt_cell_data(output.data))
    end

    puts "udts created"
  end


  def update_related_txs(code_hash)
    ApplicationRecord.transaction do
      TypeScript.where(code_hash: code_hash).map do |type_script|
        node_type = CKB::Types::Script.new(**type_script.to_node_type)
        udt = Udt.find_by(type_hash: node_type.compute_hash)
        address_id = type_script.cell_output.address.id
        generated_by_tx = type_script.cell_output.generated_by
        generated_by_tx.tags = (generated_by_tx.tags << "udt").uniq
        generated_by_tx.contained_address_ids = (generated_by_tx.contained_address_ids << address_id).uniq
        generated_by_tx.contained_udt_ids = (generated_by_tx.contained_udt_ids << udt.id).uniq
        generated_by_tx.save
        if type_script.cell_output.consumed_by_id.present?
          consumed_by_tx = type_script.cell_output.consumed_by
          consumed_by_tx.tags = (consumed_by_tx.tags << "udt").uniq
          consumed_by_tx.contained_address_ids = (consumed_by_tx.contained_address_ids << address_id).uniq
          consumed_by_tx.contained_udt_ids = (consumed_by_tx.contained_udt_ids << udt.id).uniq
          consumed_by_tx.save
        end
      end
    end
  end
end

UdtRelatedDataUpdater.new

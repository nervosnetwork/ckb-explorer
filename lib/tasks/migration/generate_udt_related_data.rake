class UdtRelatedDataGenerator
  include Rake::DSL

  def initialize
    namespace :migration do
      desc "Usage: bundle exec rake 'migration:generate_udt_related_data[true, true, true]'"
      task :generate_udt_related_data, [:create_udt, :fill_type_hash, :create_udt_accounts] => :environment do |_, args|
        create_udt if args[:create_udt].downcase == "true"
        fill_type_hash_to_cell_output if args[:fill_type_hash].downcase == "true"
        update_udt_cell_type
        if args[:create_udt_accounts].downcase == "true"
          udt_infos = CellOutput.udt.pluck(:type_hash, :address_id).uniq
          create_udt_accounts(udt_infos)
          update_udt_info(udt_infos)
        end

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
        udt = Udt.find_or_create_by!(type_hash: info[0], code_hash: udt_info[:code_hash], udt_type: "sudt")
        { udt_id: udt.id, udt_type: Udt.udt_types[udt.udt_type], full_name: udt.full_name, symbol: udt.symbol, decimal: udt.decimal, published: udt.published, code_hash: udt.code_hash, type_hash: udt.type_hash, amount: amount, address_id: address.id, created_at: Time.now, updated_at: Time.now }
      end

    UdtAccount.upsert_all(udt_accounts, unique_by: :index_udt_accounts_on_type_hash_and_address_id)
    puts "udt accounts created"
  end

  def update_udt_cell_type
    CellOutput.where(type_hash: udt_info[:type_hash]).where.not(cell_type: "udt").update(cell_type: "udt")

    puts "cell_type updated"
  end

  def fill_type_hash_to_cell_output
    columns = %i(id type_hash cell_type)
    values =
      TypeScript.find_each.map do |type_script|
        node_type_script = CKB::Types::Script.new(code_hash: type_script.code_hash, args: type_script.args, hash_type: type_script.hash_type)
        [type_script.cell_output_id, node_type_script.compute_hash, cell_type(node_type_script, type_script.cell_output.data)]
      end

    CellOutput.import columns, values, validate: false, on_duplicate_key_update: [:type_hash, :cell_type]

    puts "type_hash filled"
  end

  def create_udt
    Udt.upsert(udt_info, unique_by: :type_hash)

    puts "udt created"
  end

  def udt_info
    icon_file = nil
    if File.exist?("#{Rails.root}/tmp/kfc2.png")
      icon_file_data = Base64.encode64(File.read("#{Rails.root}/tmp/kfc.png")).gsub("\n", "")
      icon_file = "data:image/png;base64,#{icon_file_data}"
    end
    code_hash = ["0x48dbf59b4c7ee1547238021b4869bceedf4eea6b43772e5d66ef8865b6ae7212".delete_prefix(Settings.default_hash_prefix)].pack("H*")
    {
      "code_hash": code_hash,
      "hash_type": "data",
      "args": "0x6a242b57227484e904b4e08ba96f19a623c367dcbd18675ec6f2a71a0ff4ec26",
      "type_hash": "0x74c75caf537a69fcca80c1257672178f5f664573605ca109d9404b08c4251792",
      "full_name": "Kingdom Fly Coin", "symbol": "kfc", "decimal": "6", "description": "", "icon_file": icon_file,
      "operator_website": "", "udt_type": "0", "published": true, "created_at": Time.now, "updated_at": Time.now
    }
  end

  def cell_type(type_script, output_data)
      return "normal" unless [Settings.dao_code_hash, Settings.dao_type_hash, Settings.sudt_cell_type_hash].include?(type_script&.code_hash)

      case type_script&.code_hash
      when Settings.dao_code_hash, Settings.dao_type_hash
        if output_data == CKB::Utils.bin_to_hex("\x00" * 8)
          "nervos_dao_deposit"
        else
          "nervos_dao_withdrawing"
        end
      when Settings.sudt_cell_type_hash
        "udt"
      else
        "normal"
      end
  end
end

UdtRelatedDataGenerator.new

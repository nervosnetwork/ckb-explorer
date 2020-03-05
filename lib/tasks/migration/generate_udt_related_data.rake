class UdtRelatedDataGenerator
  include Rake::DSL

  def initialize
    namespace :migration do
      desc "Usage bundle exec rake 'migration:generate_udt_related_data[true, true, true]'"
      task :generate_udt_related_data, [:create_udt, :fill_type_hash, :create_udt_accounts] => :environment do |_, args|
        create_udt if !!args[:create_udt]
        fill_type_hash_to_cell_output if !!args[:fill_type_hash]
        update_udt_cell_type
        if !!args[:create_udt_accounts]
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
    udt_infos.each do |info|
      address = Address.find(info[1])
      udt_account = address.udt_accounts.find_by(type_hash: info[0])
      udt_live_cell_data = address.cell_outputs.live.udt.where(type_hash: info[0]).pluck(:data)
      amount = udt_live_cell_data.map { |data| CkbUtils.parse_udt_cell_data(data) }.sum
      if udt_account.blank?
        udt = Udt.find_or_create_by!(type_hash: info[0], code_hash: udt_info[:code_hash], udt_type: "sudt")
        address.udt_accounts.create!(udt_type: udt.udt_type, full_name: udt.full_name, symbol: udt.symbol, decimal: udt.decimal, published: udt.published, code_hash: udt.code_hash, type_hash: udt.type_hash, amount: amount)
      end
    end

    puts "udt accounts created"
  end

  def update_udt_cell_type
    CellOutput.where(type_hash: udt_info[:type_hash]).where.not(cell_type: "udt").update(cell_type: "udt")

    puts "cell_type updated"
  end

  def fill_type_hash_to_cell_output
    columns = %i(id type_hash)
    values =
      TypeScript.find_each.map do |type_script|
        node_type_script = CKB::Types::Script.new(code_hash: type_script.code_hash, args: type_script.args, hash_type: type_script.hash_type)
        [type_script.cell_output_id, node_type_script.compute_hash]
      end

    CellOutput.import columns, values, validate: false, on_duplicate_key_update: [:hash_type]

    puts "type_hash filled"
  end

  def create_udt
    puts "udt created" if Udt.create(udt_info)
  end

  def udt_info
    {
      "code_hash": "0x48dbf59b4c7ee1547238021b4869bceedf4eea6b43772e5d66ef8865b6ae7212",
      "hash_type": "data",
      "args": "0x6a242b57227484e904b4e08ba96f19a623c367dcbd18675ec6f2a71a0ff4ec26",
      "type_hash": "0x2c0da3548618bc98003075f2deabd3569c4c4a1a55e63b2e7677aeed9c45c2b7",
      "full_name": "Kingdom Fly Coin", "symbol": "kfc", "decimal": "6", "description": "", "icon_file": "",
      "operator_website": "", "udt_type": "sudt", "published": "true"
    }
  end
end

UdtRelatedDataGenerator.new

class SsriContractWorker
  include Sidekiq::Job

  DECIMAL_METHOD = "2f87f08056af234d"

  def perform(contract_ids)
    missed_contract_ids = find_missed_contract_ids(contract_ids)
    return if missed_contract_ids.empty?

    contracts = Contract.where(id: missed_contract_ids)
    attrs = build_ssri_contract_attributes(contracts)

    SsriContract.upsert_all(attrs, unique_by: :contract_id)
  end

  private

  def find_missed_contract_ids(contract_ids)
    existing_ids = SsriContract.where(contract_id: contract_ids).pluck(:contract_id)
    contract_ids - existing_ids
  end

  def build_ssri_contract_attributes(contracts)
    contracts.map do |contract|
      methods = fetch_methods(contract)
      code_hash, hash_type = contract.code_hash_hash_type
      is_udt = DECIMAL_METHOD.in?(methods)
      save_udt!(contract) if is_udt

      {
        contract_id: contract.id,
        methods: methods,
        is_udt: is_udt,
        code_hash: code_hash,
        hash_type: hash_type,
      }
    end
  end

  def fetch_methods(contract)
    raw_methods = SsriIndexer.instance.fetch_methods(
      contract.deployed_cell_output.tx_hash,
      contract.deployed_cell_output.cell_index,
    )
    hex = raw_methods.delete_prefix("0x")
    methods_length = [hex.slice(0, 8)].pack("H*").unpack1("L<")
    hex.slice(8, methods_length * 16).scan(/.{16}/)
  rescue StandardError => e
    Rails.logger.error("Error fetching methods for contract #{contract.id}: #{e.message}")
    []
  end

  def save_udt!(contract)
    code_hash, hash_type = contract.code_hash_hash_type
    scripts = TypeScript.where(code_hash: code_hash, hash_type: hash_type)

    udt_account_attrs = Set.new
    cell_output_attrs = Set.new
    udt_transaction_attrs = Set.new

    scripts.each do |script|
      udt_info = fetch_udt_info(contract, script)
      base_attr = build_base_udt_attrs(script, udt_info)
      first_output = CellOutput.live.where(type_script_id: script.id).order("block_timestamp asc").limit(1).first
      first_output.ckb_transaction.tags |= ["ssri"]
      first_output.ckb_transaction.save!
      udt = Udt.find_or_create_by!(base_attr.merge(hash_type: script.hash_type, args: script.args, icon_file: udt_info[:icon], block_timestamp: first_output.block_timestamp,
                                                   issuer_address: first_output.address.address_hash))

      CellOutput.live.where(type_script_id: script.id).each do |cell_output|
        udt_amount = CkbUtils.parse_udt_cell_data(cell_output.binary_data)

        udt_account_attrs << base_attr.merge(
          amount: udt_amount,
          address_id: cell_output.address_id,
          udt_id: udt.id,
        )

        cell_output_attrs << {
          tx_hash: cell_output.tx_hash,
          cell_index: cell_output.cell_index,
          status: cell_output.status,
          udt_amount: udt_amount,
          cell_type: "ssri",
        }

        udt_transaction_attrs << {
          udt_id: udt.id,
          ckb_transaction_id: cell_output.ckb_transaction_id,
        }
      end
    end

    UdtAccount.upsert_all(udt_account_attrs.to_a, unique_by: %i[type_hash address_id])
    UdtTransaction.upsert_all(udt_transaction_attrs.to_a, unique_by: %i[udt_id ckb_transaction_id])
    CellOutput.upsert_all(cell_output_attrs.to_a, unique_by: %i[tx_hash cell_index status])
  end

  def fetch_udt_info(contract, script)
    SsriIndexer.instance.fetch_all_udt_fields(
      contract.deployed_cell_output.tx_hash,
      contract.deployed_cell_output.cell_index,
      {
        code_hash: script.code_hash,
        hash_type: script.hash_type,
        args: script.args,
      },
    )
  end

  def build_base_udt_attrs(script, udt_info)
    {
      code_hash: script.code_hash,
      type_hash: script.script_hash,
      published: true,
      full_name: udt_info[:name],
      symbol: udt_info[:symbol],
      decimal: udt_info[:decimal],
      udt_type: "ssri",
    }
  end
end

class SsriContractWorker
  include Sidekiq::Job

  DECIMAL_METHOD = "2f87f08056af234d"

  def perform
    contracts = Contract.where.missing(:ssri_contract).limit(100)
    if contracts.present?
      attrs =
        contracts.map do |contract|
          methods = fetch_methods(contract)
          is_udt = false
          if DECIMAL_METHOD.in?(methods)
            is_udt = true
          end
          { contract_id: contract.id, methods:, is_udt: }
        end

      SsriContract.upsert_all(attrs, unique_by: :contract_id)
    end
  end

  private

  def fetch_methods(contract)
    raw_methods = SsriIndexer.instance.fetch_methods(contract.deployed_cell_output.tx_hash, contract.deployed_cell_output.cell_index)
    hex = raw_methods.delete_prefix("0x")
    methods_length = [hex.slice(0, 8)].pack("H*").unpack1("L<")
    data = hex.slice(8, methods_length * 16)
    data.scan(/.{16}/)
  rescue StandardError => e
    Rails.logger.error("Error fetching methods for contract #{contract.id}: #{e.message}")
    []
  end
end

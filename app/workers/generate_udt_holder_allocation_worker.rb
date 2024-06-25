class GenerateUdtHolderAllocationWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3

  def perform(type_hash)
    udt = Udt.find_by(type_hash:)
    return unless udt

    update_udt_holder_allocation(udt)
    update_contract_holder_allocation(udt)
  end

  def update_udt_holder_allocation(udt)
    type_script = TypeScript.find_by(udt.type_script)
    return unless type_script

    holder_allocation = UdtHolderAllocation.find_or_initialize_by(udt:, contract_id: nil)
    ckb_address_ids = CellOutput.live.where(type_script:).distinct.pluck(:address_id)
    btc_address_ids = []
    ckb_address_ids.each_slice(1000) do |address_ids|
      ids = BitcoinAddressMapping.where(ckb_address_id: address_ids).pluck(:bitcoin_address_id)
      btc_address_ids.concat(ids).uniq!
    end

    holder_allocation.update!(ckb_holder_count: ckb_address_ids.count, btc_holder_count: btc_address_ids.count)
  end

  def update_contract_holder_allocation(udt)
    contracts = Contract.where(role: ["LockScript", "lock_script"])
    contracts.each do |contract|
      holder_allocation = UdtHolderAllocation.find_or_initialize_by(udt:, contract:)
      type_script = TypeScript.find_by(udt.type_script)
      next unless type_script

      ckb_holder_count = contract.referring_cell_outputs.live.where(type_script:).distinct.count(:address_id)
      holder_allocation.update!(ckb_holder_count:)
    end
  end
end

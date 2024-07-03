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

    btc_address_ids = fetch_btc_address_ids(type_script)
    holder_allocation = UdtHolderAllocation.find_or_initialize_by(udt:, contract_id: nil)
    holder_allocation.update!(btc_holder_count: btc_address_ids.count)
  end

  def update_contract_holder_allocation(udt)
    type_script = TypeScript.find_by(udt.type_script)
    return unless type_script

    unique_ckb_address_ids = []
    CellOutput.live.where(type_script:).find_in_batches(batch_size: 1000) do |batch|
      batch_ckb_address_ids = batch.pluck(:address_id)
      excluded_ckb_address_ids = BitcoinAddressMapping.where(ckb_address_id: batch_ckb_address_ids).pluck(:ckb_address_id)
      filtered_ckb_address_ids = batch_ckb_address_ids - excluded_ckb_address_ids
      unique_ckb_address_ids.concat(filtered_ckb_address_ids).uniq!
    end

    allocation_data = {}
    unique_ckb_address_ids.each_slice(1000) do |batch_address_ids|
      holder_count = CellOutput.joins(:lock_script).
        where(address_id: batch_address_ids).
        group("lock_scripts.code_hash").
        count("DISTINCT cell_outputs.address_id")

      holder_count.each do |code_hash, count|
        allocation_data[code_hash] ||= 0
        allocation_data[code_hash] += count
      end
    end

    allocation_data.each do |code_hash, count|
      contract = Contract.find_by(code_hash:, role: ["LockScript", "lock_script"])
      next unless contract

      allocation = UdtHolderAllocation.find_or_initialize_by(udt:, contract:)
      allocation.update!(ckb_holder_count: count)
    end
  end

  private

  def fetch_btc_address_ids(type_script)
    btc_address_ids = Concurrent::Set.new
    futures = []

    CellOutput.live.where(type_script:).find_in_batches(batch_size: 1000) do |batch|
      futures << Concurrent::Promises.future do
        batch_ckb_address_ids = batch.pluck(:address_id)
        ids = BitcoinAddressMapping.where(ckb_address_id: batch_ckb_address_ids).pluck(:bitcoin_address_id)
        btc_address_ids.merge(ids)
      end
    end

    # 等待所有的 Future 完成
    Concurrent::Promises.zip(*futures).value!

    btc_address_ids
  end
end

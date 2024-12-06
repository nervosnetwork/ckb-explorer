class GenerateUdtHolderAllocationWorker
  include Sidekiq::Job

  def perform(type_hashes = nil)
    type_hashes ||= $redis.smembers("udt_holder_allocation")

    type_hashes.each do |type_hash|
      udt = Udt.find_by(type_hash:, published: true)
      next unless udt

      update_btc_holder_allocation(udt)
      update_contract_holder_allocation(udt)

      $redis.srem("udt_holder_allocation", type_hash)
    rescue StandardError => e
      Rails.logger.error("Generate #{type_hash} holder allocation failed: #{e.message}")
    end
  end

  private

  def update_btc_holder_allocation(udt)
    btc_holder_count = calculate_btc_holder_count(udt)
    holder_allocation = UdtHolderAllocation.find_or_initialize_by(udt:, contract_id: nil)
    holder_allocation.update!(btc_holder_count:)
  end

  def update_contract_holder_allocation(udt)
    unique_ckb_address_ids = fetch_unique_ckb_address_ids(udt)
    allocation_data = calculate_holder_allocation_data(unique_ckb_address_ids)

    existing_allocations = udt.udt_holder_allocations.where.not(contract_id: nil)
    existing_allocations.each do |allocation|
      unless allocation_data.key?(allocation.contract.code_hash)
        allocation.destroy!
      end
    end

    allocation_data.each do |code_hash, count|
      contract = Contract.find_by(code_hash:, is_lock_script: true)
      next unless contract

      holder_allocation = UdtHolderAllocation.find_or_initialize_by(udt:, contract:)
      holder_allocation.update!(ckb_holder_count: count)
    end
  end

  def calculate_btc_holder_count(udt)
    btc_address_ids = Set.new

    fetch_batches_of_addresses(udt) do |batch_address_ids|
      btc_ids = BitcoinAddressMapping.where(ckb_address_id: batch_address_ids).pluck(:bitcoin_address_id).uniq
      btc_address_ids.merge(btc_ids)
    end

    btc_address_ids.count
  end

  def fetch_unique_ckb_address_ids(udt)
    unique_ckb_address_ids = Set.new

    fetch_batches_of_addresses(udt) do |batch_address_ids|
      excluded_ckb_address_ids = BitcoinAddressMapping.where(ckb_address_id: batch_address_ids).pluck(:ckb_address_id)
      filtered_ckb_address_ids = batch_address_ids.to_set - excluded_ckb_address_ids.to_set
      unique_ckb_address_ids.merge(filtered_ckb_address_ids)
    end

    unique_ckb_address_ids.to_a
  end

  def fetch_batches_of_addresses(udt)
    UdtAccount.where(udt_id: udt.id).where("amount > 0").find_in_batches(batch_size: 500) do |batch|
      batch_address_ids = batch.pluck(:address_id).uniq
      yield(batch_address_ids)
    end
  end

  def calculate_holder_allocation_data(unique_ckb_address_ids)
    allocation_data = {}

    unique_ckb_address_ids.each_slice(500) do |batch_address_ids|
      lock_script_ids = Address.where(id: batch_address_ids).map(&:lock_script_id).uniq
      holder_counts = LockScript.where(id: lock_script_ids).group(:code_hash).count("DISTINCT id")
      holder_counts.each do |code_hash, count|
        allocation_data[code_hash] ||= 0
        allocation_data[code_hash] += count
      end
    end

    allocation_data
  end
end

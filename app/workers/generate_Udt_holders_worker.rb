class GenerateUdtHoldersWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3

  def perform(type_hash)
    udt = Udt.find_by(type_hash:)
    return unless udt

    type_script = TypeScript.find_by(udt.type_script)
    return unless type_script

    ckb_address_ids = CellOutput.where(type_script_id: type_script.id).pluck(:address_id).uniq
    bitcoin_address_ids = []
    ckb_address_ids.each_slice(1000) do |address_ids|
      ids = BitcoinAddressMapping.where(ckb_address_id: address_ids).pluck(:bitcoin_address_id)
      bitcoin_address_ids.concat(ids).uniq!
    end

    cache_key = "udt_holders/#{type_hash}"
    cache_value = { ckb_holders_count: ckb_address_ids.count, btc_holders_count: bitcoin_address_ids.count }
    Rails.cache.write(cache_key, cache_value)
  end
end

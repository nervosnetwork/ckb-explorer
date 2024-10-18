class UpdateUdtInfoWorker
  include Sidekiq::Job
  sidekiq_options queue: "low"

  def perform(block_number)
    local_block = Block.find_by(number: block_number)
    return if local_block.blank?

    type_hashes = []
    local_block.cell_outputs.where(cell_type: ["udt", "omiga_inscription", "xudt", "xudt_compatible"]).
      select(:id, :type_hash).each do |udt_output|
      type_hashes << udt_output.type_hash
    end
    local_block.ckb_transactions.pluck(:id).each do |tx_id|
      CellOutput.where(consumed_by_id: tx_id).udt.select(:id, :type_hash).each do |udt_output|
        type_hashes << udt_output.type_hash
      end
    end
    return if type_hashes.blank?

    amount_info = UdtAccount.where(type_hash: type_hashes).group(:type_hash).sum(:amount)
    addresses_count_info = UdtAccount.where(type_hash: type_hashes).group(:type_hash).count(:address_id)
    udts_attributes = Set.new
    type_hashes.each do |type_hash|
      udt = Udt.where(type_hash:).select(:id, :udt_type).take!
      ckb_transactions_count = UdtTransaction.where(udt_id: udt.id).count
      udts_attributes << {
        type_hash:,
        total_amount: amount_info[type_hash],
        addresses_count: addresses_count_info[type_hash],
        ckb_transactions_count:,
      }

      # generate udt holder allocation
      if udt.xudt_compatible? || udt.xudt? || udt.omiga_inscription?
        $redis.sadd("udt_holder_allocation", type_hash)
      end
    end

    if udts_attributes.present?
      Udt.upsert_all(
        udts_attributes.map! do |attr|
          attr.merge!(updated_at: Time.current)
        end, unique_by: :type_hash
      )
    end
  end
end

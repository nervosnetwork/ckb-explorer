class AddressUnclaimedCompensationGenerator
  include Sidekiq::Worker

  def perform
    Address.where(is_depositor: true).find_in_batches do |addresses|
      values =
        addresses.map do |address|
          {
            id: address.id,
            unclaimed_compensation: address.cal_unclaimed_compensation,
            created_at: address.created_at,
            updated_at: Time.current
          }
        end

      if values.present?
        values.each_slice(500) do |batch|
          Address.upsert_all(batch)
        end
        addresses.map(&:flush_cache)
      end
    end
  end
end

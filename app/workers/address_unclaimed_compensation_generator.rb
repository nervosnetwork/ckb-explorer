class AddressUnclaimedCompensationGenerator
  include Sidekiq::Worker

  def perform
    Address.where("dao_deposit > 0").find_in_batches do |addresses|
      values =
        addresses.map do |address|
          { id: address.id, unclaimed_compensation: address.cal_unclaimed_compensation, created_at: address.created_at, updated_at: Time.current }
        end

      Address.upsert_all(values)
    end
  end
end

class DaoContractSerializer
  include FastJsonapi::ObjectSerializer
  set_type :nervos_dao
  attribute :total_deposit do |object|
    object.total_deposit.to_s
  end
  attribute :depositors_count do |object|
    object.depositors_count.to_s
  end
  attribute :deposit_changes do |object|
    object.deposit_changes.to_s
  end
  attribute :unclaimed_compensation_changes do |object|
    object.unclaimed_compensation_changes.to_s
  end
  attribute :claimed_compensation_changes do |object|
    object.claimed_compensation_changes.to_s
  end
  attribute :depositor_changes do |object|
    object.depositor_changes.to_s
  end
  attribute :unclaimed_compensation do |object|
    object.unclaimed_compensation.to_s
  end
  attribute :claimed_compensation do |object|
    object.claimed_compensation.to_s
  end
  attribute :average_deposit_time do |object|
    object.average_deposit_time.to_s
  end
  attribute :mining_reward do |object|
    object.mining_reward.to_s
  end
  attribute :deposit_compensation do |object|
    object.deposit_compensation.to_s
  end
  attribute :treasury_amount do |object|
    object.treasury_amount.to_s
  end
  attribute :estimated_apc do |object|
    object.estimated_apc.to_s
  end
end

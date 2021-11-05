class AddressSerializer
  include FastJsonapi::ObjectSerializer

  attributes :lock_info

  attribute :address_hash do |object|
    object.query_address
  end
  attribute :balance do |object|
    object.balance.to_s
  end
  attribute :transactions_count do |object|
    object.ckb_transactions_count.to_s
  end
  attribute :dao_deposit do |object|
    object.dao_deposit.to_s
  end
  attribute :interest do |object|
    object.interest.to_s
  end
  attribute :is_special do |object|
    object.special?.to_s
  end
  attribute :special_address, if: Proc.new { |record| record.special? } do |object|
    Settings.special_addresses[object.address_hash]
  end
  attribute :live_cells_count do |object|
    object.live_cells_count.to_s
  end
  attribute :mined_blocks_count do |object|
    object.mined_blocks_count.to_s
  end
  attribute :average_deposit_time do |object|
    object.average_deposit_time.to_s
  end
  attribute :udt_accounts do |object|
    if object.udt_accounts.present?
      object.udt_accounts.published.map do |udt_account|
        if udt_account.udt_type == "sudt"
          { symbol: udt_account.symbol, decimal: udt_account.decimal.to_s, amount: udt_account.amount.to_s, type_hash: udt_account.type_hash, udt_icon_file: udt_account.udt_icon_file, udt_type: udt_account.udt_type }
        elsif udt_account.udt_type == "m_nft_token"
          { symbol: udt_account.full_name, decimal: udt_account.decimal.to_s, amount: udt_account.amount.to_s, type_hash: udt_account.type_hash, udt_icon_file: udt_account.udt_icon_file, udt_type: udt_account.udt_type }
        end
      end
    else
      []
    end
  end
  attribute :lock_script do |object|
    object.cached_lock_script
  end
  attribute :dao_compensation do |object|
    (object.interest + object.unclaimed_compensation.to_i).to_s
  end
  attribute :balance_occupied do |object|
    object.balance_occupied.to_s
  end
end

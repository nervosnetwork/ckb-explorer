class AddressSerializer
  include FastJsonapi::ObjectSerializer

  attributes :address_hash, :lock_script
  attribute :balance do |object|
    object.balance.to_s
  end
  attribute :transactions_count do |object|
    object.transactions_count.to_s
  end
  attribute :pending_reward_blocks_count do |object|
    object.pending_reward_blocks_count.to_s
  end
  attribute :dao_deposit do |object|
    object.dao_deposit.to_s
  end
  attribute :interest do |object|
    object.interest.to_s
  end
  attribute :lock_info do |object|
    parsed_result = CkbUtils.parse_address(object.address_hash)
    bin_args = CKB::Utils.hex_to_bin(parsed_result.script.args)
    if parsed_result.address_type == "FULL" && bin_args.bytesize == 28
      since = CKB::Utils.bin_to_hex(bin_args[-8..-1]).delete_prefix("0x")
      begin
        since_value = SinceParser.new(since).parse
        if since_value.present?
          tip_epoch_number = CkbSync::Api.instance.get_current_epoch.number
          lock_status = tip_epoch_number > since_value.number ? "locked" : "unlocked"

          { status: lock_status, epoch_number: since_value.number.to_s, epoch_index: since_value.index.to_s }
        end
      ensure SinceParser::IncorrectSinceFlagsError
        nil
      end
    end
  end
end

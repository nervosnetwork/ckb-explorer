class LockScript < ApplicationRecord
  belongs_to :address

  validates_presence_of :code_hash

  attribute :code_hash, :ckb_hash

  def cell_output
    CellOutput.find(cell_output_id)
  end

  def to_node_lock
    {
      args: args,
      code_hash: code_hash,
      hash_type: hash_type
    }
  end

  def lock_info
    bin_args = CKB::Utils.hex_to_bin(args)
    if code_hash == ENV["SECP_MULTISIG_CELL_TYPE_HASH"] && bin_args.bytesize == 28
      since = CKB::Utils.bin_to_hex(bin_args[-8..-1]).delete_prefix("0x")
      begin
        since_value = SinceParser.new(since).parse
        return if since_value.blank?

        tip_epoch = CkbUtils.parse_epoch(CkbSync::Api.instance.get_tip_header.epoch)
        epoch_number, since_value_index = set_since_epoch_number_and_index(since_value)
        block_interval = (epoch_number * 1800 + since_value_index * 1800 / since_value.length) - (tip_epoch.number * 1800 + tip_epoch.index * 1800 / tip_epoch.length)

        if block_interval.negative?
          block = Block.where(epoch: since_value.number).recent.first
          new_index = since_value_index < block.length ? since_value_index : since_value_index * block.length / since_value.length
          block_timestamp = Block.where(number: block.start_number + new_index).pick(:timestamp)
          estimated_unlock_time = DateTime.strptime(block_timestamp.to_s, "%Q")
        else
          tip_block_timestamp = Block.recent.where(epoch: tip_epoch.number).pick(:timestamp)
          tip_block_time = DateTime.strptime(tip_block_timestamp.to_s, "%Q")
          estimated_unlock_time = tip_block_time + (block_interval * 8).seconds
        end

        { status: lock_info_status(since_value, tip_epoch), epoch_number: epoch_number.to_s, epoch_index: since_value_index.to_s, estimated_unlock_time: estimated_unlock_time.strftime("%Q") }
      rescue SinceParser::IncorrectSinceFlagsError
        nil
      end
    end
  end

  private

  def set_since_epoch_number_and_index(since_value)
    if since_value.index > since_value.length
      epoch_number = since_value.number + 1
      since_value_index = 0
    else
      epoch_number = since_value.number
      since_value_index = since_value.index
    end

    return epoch_number, since_value_index
  end

  def lock_info_status(since_value, tip_epoch)
    after_lock_epoch_number = tip_epoch.number > since_value.number
    at_lock_epoch_number_but_exceeded_index = (tip_epoch.number == since_value.number &&
      tip_epoch.index * since_value.length > since_value.index * tip_epoch.length)

    after_lock_epoch_number || at_lock_epoch_number_but_exceeded_index ? "unlocked" : "locked"
  end
end

# == Schema Information
#
# Table name: lock_scripts
#
#  id             :bigint           not null, primary key
#  args           :string
#  code_hash      :binary
#  cell_output_id :bigint
#  address_id     :bigint
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  hash_type      :string
#
# Indexes
#
#  index_lock_scripts_on_address_id      (address_id)
#  index_lock_scripts_on_cell_output_id  (cell_output_id)
#

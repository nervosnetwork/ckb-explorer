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

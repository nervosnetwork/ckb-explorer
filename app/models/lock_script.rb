class LockScript < ApplicationRecord
  has_many :cell_outputs

  # TODO remove this
  has_many :ckb_transactions, source: :ckb_transaction, through: :cell_outputs
  has_many :consumed_by_txs, source: :consumed_by, through: :cell_outputs
  has_one :address

  validates_presence_of :code_hash
  attribute :code_hash, :ckb_hash

  scope :lock_script, ->(type_hash, data_hash) { where(code_hash: [type_hash, data_hash]) }
  scope :zero_lock, -> { where(code_hash: Contract::ZERO_LOCK_HASH) }

  def to_ckb_type
    OpenStruct.new(code_hash: code_hash,
                   hash_type: hash_type,
                   args: args)
  end

  def to_node
    {
      args:,
      code_hash:,
      hash_type:,
    }
  end

  def as_json(_options = {})
    {
      args:,
      code_hash:,
      hash_type:,
      script_hash:,
    }
  end

  def ckb_transactions
    CkbTransaction.where(id: CellOutput.where(lock_script_id: id).pluck("ckb_transaction_id",
                                                                        "consumed_by_id").flatten)
  end

  def cell_output
    CellOutput.find(cell_output_id)
  end

  def lock_info
    bin_args = CKB::Utils.hex_to_bin(args)
    if code_hash == Settings.secp_multisig_cell_type_hash && bin_args.bytesize == 28
      since = CKB::Utils.bin_to_hex(bin_args[-8..-1]).delete_prefix("0x")
      begin
        since_value = SinceParser.new(since).parse
        return if since_value.blank?

        tip_block = Block.recent.first
        tip_epoch = tip_epoch(tip_block)

        epoch_number, since_value_index = set_since_epoch_number_and_index(since_value)
        block_interval = ((epoch_number * 1800) + (since_value_index * 1800 / since_value.length)) - ((tip_epoch.number * 1800) + (tip_epoch.index * 1800 / tip_epoch.length))

        if block_interval.negative?
          block = Block.where(epoch: since_value.number).order(number: :desc).select(:start_number, :length)[0]
          new_index = since_value_index < block.length ? since_value_index : since_value_index * block.length / since_value.length
          block_timestamp = Block.where(number: block.start_number + new_index).pick(:timestamp)
          estimated_unlock_time = DateTime.strptime(block_timestamp.to_s, "%Q")
        else
          tip_block_timestamp = tip_block.timestamp
          tip_block_time = DateTime.strptime(tip_block_timestamp.to_s, "%Q")
          estimated_unlock_time = tip_block_time + (block_interval * 8).seconds
        end

        {
          status: lock_info_status(since_value, tip_epoch), epoch_number: epoch_number.to_s,
          epoch_index: since_value_index.to_s, estimated_unlock_time: estimated_unlock_time.strftime("%Q")
        }
      rescue SinceParser::IncorrectSinceFlagsError
        nil
      end
    end
  end

  # @return [Integer] Byte
  def calculate_bytesize
    bytesize = 1
    bytesize += CKB::Utils.hex_to_bin(code_hash).bytesize if code_hash
    bytesize += CKB::Utils.hex_to_bin(args).bytesize if args

    bytesize
  end

  def verified_script
    if hash_type == "type"
      Contract.live_verified.where(type_hash: code_hash)&.first
    else
      Contract.live_verified.where(data_hash: code_hash)&.first
    end
  end

  def tags
    result_tags = []
    result_tags << "multisig" if (code_hash == Settings.multisig_code_hash && hash_type == "data1") ||
      (code_hash == Settings.secp_multisig_cell_type_hash && hash_type == "type")
    result_tags << "multisig_time_lock" if result_tags.include?("multisig") && args.length === (28 * 2) + 2
    result_tags << "btc_time_lock" if Settings.btc_time_code_hash.include?(code_hash) && hash_type == "type"
    result_tags << "rgb++" if Settings.rgbpp_code_hash.include?(code_hash) && hash_type == "type"
    result_tags
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

    [epoch_number, since_value_index]
  end

  def lock_info_status(since_value, tip_epoch)
    after_lock_epoch_number = tip_epoch.number > since_value.number
    at_lock_epoch_number_but_exceeded_index = tip_epoch.number == since_value.number &&
      tip_epoch.index * since_value.length > since_value.index * tip_epoch.length

    after_lock_epoch_number || at_lock_epoch_number_but_exceeded_index ? "unlocked" : "locked"
  end

  def tip_epoch(tip_block)
    @tip_epoch ||=
      begin
        tip_epoch_index = tip_block.number - tip_block.start_number
        OpenStruct.new(number: tip_block.epoch, index: tip_epoch_index, length: tip_block.length)
      end
  end
end

# == Schema Information
#
# Table name: lock_scripts
#
#  id          :bigint           not null, primary key
#  args        :string
#  code_hash   :binary
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  hash_type   :string
#  script_hash :string
#
# Indexes
#
#  index_lock_scripts_on_code_hash_and_hash_type_and_args  (code_hash,hash_type,args)
#  index_lock_scripts_on_script_hash                       (script_hash) UNIQUE
#

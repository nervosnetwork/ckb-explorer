class CellInput < ApplicationRecord
  attr_accessor :previous_output

  belongs_to :ckb_transaction
  belongs_to :previous_cell_output, class_name: "CellOutput", optional: true
  belongs_to :block, optional: true

  delegate :lock_script, :type_script, to: :previous_cell_output, allow_nil: true

  enum cell_type: {
    normal: 0, nervos_dao_deposit: 1, nervos_dao_withdrawing: 2, udt: 3, m_nft_issuer: 4,
    m_nft_class: 5, m_nft_token: 6, nrc_721_token: 7, nrc_721_factory: 8, cota_registry: 9, cota_regular: 10 }
  def output
    previous_cell_output
  end

  def hex_since
    "0x#{since.to_s(16)}"
  end

  def to_raw
    if previous_cell_output
      {
        previous_output: {
          index: "0x#{(previous_index || previous_cell_output.cell_index).to_s(16)}",
          tx_hash: previous_tx_hash || previous_cell_output.tx_hash
        },
        since: hex_since
      }
    else
      {
        previous_output: {
          index: "0xffffffff",
          tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000"
        },
        since: hex_since
      }
    end
  end

  before_validation :match_cell_output

  def cache_keys
    %W(CellInput/#{id}/lock_script CellInput/#{id}/type_script)
  end

  def flush_cache
    $redis.pipelined do
      Rails.cache.delete_multi(cache_keys)
    end
  end

  def match_cell_output
    if previous_output
      self.previous_output = previous_output.with_indifferent_access
      self.previous_tx_hash = previous_output["tx_hash"]
      index = previous_output["index"]
      self.previous_index = index.is_a?(String) ? index.hex : index
    end
    if previous_tx_hash && previous_tx_hash != CellOutput::SYSTEM_TX_HASH
      self.previous_cell_output = CellOutput.find_by(tx_hash: previous_tx_hash,
                                                     cell_index: previous_index)
    end
  end

  def self.clean_data
  end
end

# == Schema Information
#
# Table name: cell_inputs
#
#  id                      :bigint           not null, primary key
#  ckb_transaction_id      :bigint
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  previous_cell_output_id :bigint
#  from_cell_base          :boolean          default(FALSE)
#  block_id                :decimal(30, )
#  since                   :decimal(30, )    default(0)
#  cell_type               :integer          default("normal")
#  index                   :integer
#  previous_tx_hash        :binary
#  previous_index          :integer
#
# Indexes
#
#  index_cell_inputs_on_block_id                             (block_id)
#  index_cell_inputs_on_ckb_transaction_id                   (ckb_transaction_id)
#  index_cell_inputs_on_previous_cell_output_id              (previous_cell_output_id)
#  index_cell_inputs_on_previous_tx_hash_and_previous_index  (previous_tx_hash,previous_index)
#

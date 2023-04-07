class CellInput < ApplicationRecord
  belongs_to :ckb_transaction
  belongs_to :block

  enum cell_type: { normal: 0, nervos_dao_deposit: 1, nervos_dao_withdrawing: 2, udt: 3, m_nft_issuer: 4, m_nft_class: 5, m_nft_token: 6, nrc_721_token: 7, nrc_721_factory: 8, cota_registry: 9, cota_regular: 10 }

  after_commit :flush_cache

  def find_lock_script!
    Rails.cache.realize(["CellInput", id, "lock_script"], race_condition_ttl: 3.seconds) do
      previous_cell_output!.lock_script
    end
  end

  def find_type_script!
    Rails.cache.realize(["CellInput", id, "type_script"], race_condition_ttl: 3.seconds) do
      previous_cell_output!.type_script
    end
  end

  def find_cell_output!
    previous_cell_output!
  end

  def previous_cell_output
    return if previous_output["tx_hash"] == CellOutput::SYSTEM_TX_HASH

    tx_hash = previous_output["tx_hash"]
    cell_index = previous_output["index"].to_i
    # CellOutput.find_by_pointer(previous_output["tx_hash"], previous_output["index"])
    CellOutput.find_by(tx_hash: tx_hash, cell_index: cell_index)
  end

  def self.cached_find(id)
    Rails.cache.realize([name, id], race_condition_ttl: 3.seconds) { find(id) }
  end

  def cache_keys
    %W(CellInput/#{id}/lock_script CellInput/#{id}/type_script)
  end

  def flush_cache
    $redis.pipelined do
      $redis.del(*cache_keys)
    end
  end

  def to_raw
    {
      previous_output: {
        index: "0x#{previous_output['index'].to_s(16)}",
        tx_hash: previous_output["tx_hash"]
      },
      since: "0x#{since.to_s(16)}"
    }
  end

  private

  def previous_cell_output!
    raise ActiveRecord::RecordNotFound if previous_output["tx_hash"] == CellOutput::SYSTEM_TX_HASH

    tx_hash = previous_output["tx_hash"]
    cell_index = previous_output["index"].to_i

    Rails.cache.realize("cell_input_#{id}/previous_cell_output/#{tx_hash}/#{cell_index}", race_condition_ttl: 3.seconds) do
      CellOutput.find_by!(tx_hash: tx_hash, cell_index: cell_index)
    end
  end
end

# == Schema Information
#
# Table name: cell_inputs
#
#  id                      :bigint           not null, primary key
#  previous_output         :jsonb
#  ckb_transaction_id      :bigint
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  previous_cell_output_id :bigint
#  from_cell_base          :boolean          default(FALSE)
#  block_id                :decimal(30, )
#  since                   :decimal(30, )    default(0)
#  cell_type               :integer          default("normal")
#
# Indexes
#
#  index_cell_inputs_on_block_id                 (block_id)
#  index_cell_inputs_on_ckb_transaction_id       (ckb_transaction_id)
#  index_cell_inputs_on_previous_cell_output_id  (previous_cell_output_id)
#

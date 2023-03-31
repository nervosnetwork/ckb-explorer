class CellInput < ApplicationRecord
  belongs_to :ckb_transaction
  belongs_to :previous_cell_output, optional: true
  belongs_to :block

  delegate :lock_script, :type_script, to: :previous_cell_output

  enum cell_type: { normal: 0, nervos_dao_deposit: 1, nervos_dao_withdrawing: 2, udt: 3, m_nft_issuer: 4, m_nft_class: 5, m_nft_token: 6, nrc_721_token: 7, nrc_721_factory: 8, cota_registry: 9, cota_regular: 10 }

  def to_raw
    if previous_cell_output
      {
        previous_output: {
          index: "0x#{previous_output.cell_index.to_s(16)}",
          tx_hash: previous_output.tx_hash
        },
        since: "0x#{since.to_s(16)}"
      }
    else
      {
        previous_output: {
          index: "0xffffffff",
          tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000"
        },
        since: "0x#{since.to_s(16)}"
      }
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

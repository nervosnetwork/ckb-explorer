class Udt < ApplicationRecord
  enum udt_type: { sudt: 0 }

  validates_presence_of :total_amount
  validates_length_of :symbol, minimum: 1, maximum: 16, allow_nil: true
  validates_length_of :full_name, minimum: 1, maximum: 32, allow_nil: true
  validates :decimal, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 39 }, allow_nil: true
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }

  attribute :code_hash, :ckb_hash

  def ckb_transactions
    type_hash = "0xe3be4fb98ec914886c6525abac97e1f8769c59492636a1d35955e9163ef46efa"
    sql =
      <<-SQL
        SELECT
          generated_by_id ckb_transaction_id
        FROM
          cell_outputs
        WHERE
          cell_type = #{CellOutput::cell_types['udt']}
          AND
          type_hash = '#{type_hash}'

        UNION

        SELECT
          consumed_by_id ckb_transaction_id
        FROM
          cell_outputs
        WHERE
          cell_type = #{CellOutput::cell_types['udt']}
          AND
          type_hash = '#{type_hash}'
          AND
          consumed_by_id is not null
      SQL
    ckb_transaction_ids = CellOutput.select("ckb_transaction_id").from("(#{sql}) as cell_outputs")
    CkbTransaction.where(id: ckb_transaction_ids.distinct)
  end
end

# == Schema Information
#
# Table name: udts
#
#  id               :bigint           not null, primary key
#  code_hash        :binary
#  hash_type        :string
#  args             :string
#  type_hash        :string
#  full_name        :string
#  symbol           :string
#  decimal          :integer
#  description      :string
#  icon_file        :string
#  operator_website :string
#  addresses_count  :decimal(30, )    default(0)
#  total_amount     :decimal(40, )    default(0)
#  udt_type         :integer
#  published        :boolean          default(FALSE)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_udts_on_type_hash  (type_hash) UNIQUE
#

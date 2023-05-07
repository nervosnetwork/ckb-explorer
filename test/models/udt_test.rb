require "test_helper"

class UdtTest < ActiveSupport::TestCase
  context "validations" do
    should validate_presence_of(:total_amount)
    should validate_numericality_of(:decimal).allow_nil.is_greater_than_or_equal_to(0).is_less_than_or_equal_to(39)
    should validate_numericality_of(:total_amount).is_greater_than_or_equal_to(0)
    should validate_length_of(:symbol).allow_nil.is_at_least(1).is_at_most(16)
    should validate_length_of(:full_name).allow_nil.is_at_least(1).is_at_most(100)
  end

  test "should return node type script when the udt is published" do
    udt = create(:udt, published: true)
    node_type_script = {
      args: udt.args,
      code_hash: udt.code_hash,
      hash_type: udt.hash_type
    }

    assert_equal node_type_script, udt.type_script
  end

  test "#ckb_transactions should return an empty array when there aren't udt cells" do
    udt = create(:udt, published: true)

    assert_equal [], udt.ckb_transactions
  end

  test "#ckb_transactions should return correct ckb_transactions when there are udt cells under the udt" do
    udt = create(:udt)
    address = create(:address)
    30.times do |number|
      block = create(:block, :with_block_hash)
      if number % 2 == 0
        tx = create(:ckb_transaction, block: block, tags: ["udt"], contained_udt_ids: [udt.id],
                                      contained_address_ids: [address.id])
        create(:cell_output, block: block, ckb_transaction: tx, cell_type: "udt", type_hash: udt.type_hash,
                             address: address)
      else
        tx = create(:ckb_transaction, block: block, tags: ["udt"], contained_udt_ids: [udt.id],
                                      contained_address_ids: [address.id])
        tx1 = create(:ckb_transaction, block: block, tags: ["udt"], contained_udt_ids: [udt.id],
                                       contained_address_ids: [address.id])
        create(:cell_output, block: block, ckb_transaction: tx1, cell_type: "udt", type_hash: udt.type_hash,
                             address: address)
        create(:cell_output, block: block, ckb_transaction: tx, cell_type: "udt", type_hash: udt.type_hash,
                             consumed_by_id: tx1, address: address)
      end
    end

    sql =
      <<-SQL
        SELECT
          ckb_transaction_id
        FROM
          cell_outputs
        WHERE
          cell_type = #{CellOutput::cell_types['udt']}
          AND
          type_hash = '#{udt.type_hash}'

        UNION

        SELECT
          consumed_by_id ckb_transaction_id
        FROM
          cell_outputs
        WHERE
          cell_type = #{CellOutput::cell_types['udt']}
          AND
          type_hash = '#{udt.type_hash}'
          AND
          consumed_by_id is not null
      SQL
    ckb_transaction_ids = CellOutput.select("ckb_transaction_id").from("(#{sql}) as cell_outputs")
    expected_txs = CkbTransaction.where(id: ckb_transaction_ids.distinct).recent

    assert_equal expected_txs.pluck(:id), udt.ckb_transactions.recent.pluck(:id)
  end
end

require "test_helper"

class CkbTransactionSerializerTest < ActiveSupport::TestCase
  test "should contain correct keys" do
    ckb_transaction = create(:ckb_transaction)

    assert_equal %i(block_number transaction_hash block_timestamp transaction_fee version display_inputs display_outputs).sort, CkbTransactionSerializer.new(ckb_transaction).serializable_hash.dig(:data, :attributes).keys.sort
  end

  test "should return transaction_fee converted to ckb" do
    ckb_transaction = create(:ckb_transaction, transaction_fee: 10)

    assert_equal 0.0000001, CkbTransactionSerializer.new(ckb_transaction).serializable_hash.dig(:data, :attributes, :transaction_fee)
  end
end

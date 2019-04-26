require "test_helper"

class AddressSerializerTest < ActiveSupport::TestCase
  test "should contain correct keys" do
    address = create(:address, :with_lock_script)

    assert_equal %i(address_hash balance transactions_count cell_consumed lock_script).sort, AddressSerializer.new(address).serializable_hash.dig(:data, :attributes).keys.sort
  end

  test "should return balance converted to ckb" do
    address = create(:address, :with_lock_script, balance: 10000)

    assert_equal 0.0001, AddressSerializer.new(address).serializable_hash.dig(:data, :attributes, :balance)
  end

  test "should return cell_consumed converted to ckb" do
    address = create(:address, :with_lock_script, cell_consumed: 10000)

    assert_equal 0.0001, AddressSerializer.new(address).serializable_hash.dig(:data, :attributes, :cell_consumed)
  end
end

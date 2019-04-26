require "test_helper"

class ShannonTest < ActiveSupport::TestCase
  test "#to_i should return integer shannon" do
    shannon = Shannon.new(100000)

    assert_equal 100000, shannon.to_i
  end

  test "#to_ckb should convert shannons to tyte " do
    shannon = Shannon.new(100000)

    assert_equal 100000.to_f / 10 ** 8, shannon.to_ckb
  end

  test "#to_i should return 0 when number is 0" do
    shannon = Shannon.new

    assert_equal 0, shannon.to_i
  end

  test "#to_ckb should return 0 when number is 0" do
    shannon = Shannon.new

    assert_equal 0, shannon.to_ckb
  end
end

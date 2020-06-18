require "test_helper"

class UdtTest < ActiveSupport::TestCase
  context "validations" do
    should validate_presence_of(:total_amount)
    should validate_numericality_of(:decimal).allow_nil.is_greater_than_or_equal_to(0).is_less_than_or_equal_to(39)
    should validate_numericality_of(:total_amount).is_greater_than_or_equal_to(0)
    should validate_length_of(:symbol).allow_nil.is_at_least(1).is_at_most(16)
    should validate_length_of(:full_name).allow_nil.is_at_least(1).is_at_most(32)
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
end

require "test_helper"

class UdtTest < ActiveSupport::TestCase
  context "validations" do
    should validate_presence_of(:full_name)
    should validate_presence_of(:symbol)
    should validate_presence_of(:decimal)
    should validate_presence_of(:total_amount)
    should validate_numericality_of(:decimal).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(39)
    should validate_numericality_of(:total_amount).is_greater_than_or_equal_to(0)
    should validate_length_of(:symbol).is_at_least(1).is_at_most(16)
    should validate_length_of(:full_name).is_at_least(1).is_at_most(32)
  end
end

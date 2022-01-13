require "test_helper"

class UdtAccountTest < ActiveSupport::TestCase
  context "associations" do
    should belong_to(:address)
  end

  context "validations" do
    should validate_presence_of(:amount)
    should validate_numericality_of(:decimal).allow_nil.is_greater_than_or_equal_to(0).is_less_than_or_equal_to(39)
    should validate_numericality_of(:amount).is_greater_than_or_equal_to(0)
    should validate_length_of(:symbol).allow_nil.is_at_least(1).is_at_most(16)
    should validate_length_of(:full_name).allow_nil.is_at_least(1).is_at_most(100)
  end
end

require "test_helper"

class UdtAccountTest < ActiveSupport::TestCase
  context "associations" do
    should belong_to(:address)
  end

  context "validations" do
    should validate_presence_of(:amount)
    should validate_numericality_of(:decimal).allow_nil.is_greater_than_or_equal_to(0).is_less_than_or_equal_to(39)
    should validate_numericality_of(:amount).is_greater_than_or_equal_to(0)
  end
end

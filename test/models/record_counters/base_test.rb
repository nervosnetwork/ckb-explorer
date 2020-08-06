require "test_helper"

class BaseTest < ActiveSupport::TestCase
  test "should respond to total_count" do
    base = RecordCounters::Base.new
    assert_respond_to base, :total_count
  end
end

require "test_helper"

class BlockTransactionTest < ActiveSupport::TestCase
  context "associations" do
    should belong_to(:block)
    should belong_to(:ckb_transaction)
  end
end

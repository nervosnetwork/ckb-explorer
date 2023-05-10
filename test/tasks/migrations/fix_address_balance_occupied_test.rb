require "test_helper"
require "rake"

class FixAddressBalanceOccupiedTest < ActiveSupport::TestCase
  setup do
    @not_changed_address = create(:address, balance_occupied: 0, created_at: DateTime.new(2022, 1, 1, 0, 0, 0),
                                            updated_at: DateTime.new(2022, 1, 1, 0, 0, 0))
    @address = create(:address, balance_occupied: 0)

    @block = create :block
    create(:cell_output, :with_full_transaction, block: @block, address: @address, capacity: 16178 * (10**8),
                                                 type_hash: "0xd10b036bce0bdf91c2898718590b18d593b85a91dc64c190328bec5d647064bd", data: "0x000c")
    Server::Application.load_tasks if Rake::Task.tasks.empty?
  end

  test "update balance occupied" do
    Rake::Task["migration:fix_address_balance_occupied"].invoke

    assert_equal 16178 * (10**8), @address.balance_occupied
    assert_equal 0, @not_changed_address.balance_occupied
  end
end

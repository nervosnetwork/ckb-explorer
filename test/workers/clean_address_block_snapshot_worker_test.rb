require "test_helper"

class CleanAddressBlockSnapshotWorkerTest < ActiveJob::TestCase
  test "clean addrss block snapshot successfully" do
    address = create(:address)
    create_list(:address_block_snapshot, 60, address: address)
    assert_changes -> { AddressBlockSnapshot.count }, from: 60, to: 30 do
      CleanAddressBlockSnapshotWorker.new.perform
    end
  end
end

require "test_helper"

module Api
  module V2
    class BlocksControllerTest < ActionDispatch::IntegrationTest
      def setup
        super
        Block.delete_all
        # miner_message == '0.103.0'
        block1 = create(:block, :with_block_hash, number: 1, timestamp: 1.day.ago.to_i * 1000)
        create(:ckb_transaction, block: block1, witnesses: ["0x800000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce80114000000dde7801c073dfb3464c7b1f05b806bb2bbb84e9927000000302e3130332e302028353161383134612d646972747920323032322d30342d3230292000000000"])
        block2 = create(:block, :with_block_hash, number: 2, timestamp: 1.day.ago.to_i * 1000)
        create(:ckb_transaction, block: block2, witnesses: ["0x750000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000007164f48d7a5bf2298166f8d81b81ea4e908e16ad1c000000302e3130332e3020286537373133386520323032322d30342d313129"])
        block3 = create(:block, :with_block_hash, number: 3, timestamp: 1.day.ago.to_i * 1000)
        create(:ckb_transaction, block: block3, witnesses: ["0x750000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000007164f48d7a5bf2298166f8d81b81ea4e908e16ad1c000000302e3130332e3020286537373133386520323032322d30342d313129"])
        block4 = create(:block, :with_block_hash, number: 4, timestamp: 1.day.ago.to_i * 1000)
        cellbase = create(:ckb_transaction, block: block4, witnesses: ["0x750000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000007164f48d7a5bf2298166f8d81b81ea4e908e16ad1c000000302e3130332e3020286537373133386520323032322d30342d313129"])

        witness = Witness.new data: "0x750000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000007164f48d7a5bf2298166f8d81b81ea4e908e16ad1c000000302e3130332e3020286537373133386520323032322d30342d313129"
        Block.any_instance.stubs(:cellbase).returns(cellbase)
        CkbTransaction.any_instance.stubs(:witnesses).returns([witness])

        Block.set_ckb_node_versions_from_miner_message
      end
      test "should get ckb_node_versions " do
        assert_equal Block.all.size, 4
        get ckb_node_versions_api_v2_blocks_url
        data = JSON.parse(response.body)["data"]
        assert_equal 1, data.size

        data.each do |e|
          if e["version"] == "0.103.0"
            assert_equal 4, e["blocks_count"]
          end
        end
      end
    end
  end
end

require "test_helper"

module Api
  module V2
    class BlocksControllerTest < ActionDispatch::IntegrationTest
      def setup
        super
        block1 = create(:block, block_hash: '001', miner_message: "0x22302e3130332e3020286537373133386520323032322d30342d31312920346436393665363536343432373935363639363134323534343322", number: 1)
        block2 = create(:block, block_hash: '002', miner_message: "0x22302e3130312e332028376338393031382d646972747920323032312d31333232643331333432393230303030303030303022", number: 2)
        block3 = create(:block, block_hash: '003', miner_message: "0x22302e3130312e332028376338393031382d646972747920323032312d31333232643331333432393230303030303030303022", number: 3)
        block4 = create(:block, block_hash: '004', miner_message: "0x22302e3130312e332028376338393031382d646972747920323032312d31333232643331333432393230303030303030303022", number: 4)
        block5 = create(:block, block_hash: '005', miner_message: "0x22302e3130312e332028376338393031382d646972747920323032312d31333232643331333432393230303030303030303022", number: 5)
        Block.set_ckb_node_versions_from_miner_message
      end
      test "should get ckb_node_versions " do
        get ckb_node_versions_api_v2_blocks_url
        puts JSON.parse(response)['data']
      end
    end
  end
end

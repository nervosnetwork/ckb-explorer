require "test_helper"

class CkbUtilsTest < ActiveSupport::TestCase
  test "#generate_address should return type1 address when use default lock script" do
    type1_address = "ckt1q9gry5zgxmpjnmtrp4kww5r39frh2sm89tdt2l6v234ygf"
    lock_script = CKB::Types::Script.generate_lock(
      "0x36c329ed630d6ce750712a477543672adab57f4c",
      ENV["CODE_HASH"]
    )

    assert_equal type1_address, CkbUtils.generate_address(lock_script)
  end

  test "#base_reward should return first output capacity in cellbase for genesis block" do
    CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
      CKB::Types::Epoch.new(
        block_reward: "250000000000",
        difficulty: "0x1000",
        last_block_hash_in_previous_epoch: "0x0000000000000000000000000000000000000000000000000000000000000000",
        length: "2000",
        number: "0",
        remainder_reward: "0",
        start_number: "0"
      )
    )
    VCR.use_cassette("genesis_block") do
      SyncInfo.local_inauthentic_tip_block_number
      node_block = CkbSync::Api.instance.get_block_by_number("0")
      set_default_lock_params(node_block: node_block)

      local_block = CkbSync::Persist.save_block(node_block, "inauthentic")

      assert_equal node_block.transactions.first.outputs.first.capacity.to_i, local_block.reward
    end
  end
end
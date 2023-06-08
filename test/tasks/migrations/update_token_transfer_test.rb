require "test_helper"
require "rake"

class UpdateTokenTransferTest < ActiveSupport::TestCase
  setup do
    CotaAggregator.any_instance.stubs(:get_transactions_by_block_number).returns({
      "block_number" => 9939607,
      "transactions" => [
        {
          "block_number" => 9939607,
          "cota_id" => "0x1e23dc506c1b15f286c9db84a4d12a4532660975",
          "from" => "ckt1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsqwuwrenm6r0muupkn79huyjhv3aqfm5sqg5xwwyx",
          "to" => "ckt1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsqfrkrvjpk2e7p6e90t9sc65ahf7wjhwzqq26rfzt",
          "token_index" => "0x00000000",
          "tx_hash" => "0xc938c9acf95a351c2de70494b1fabc22d625fd1664741535e1058e60d454738f",
          "tx_type" => "transfer"
        }
      ]
    })
    CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb"))
    Server::Application.load_tasks if Rake::Task.tasks.empty?
  end

  test "update token transfer action" do
    collection = create(:token_collection, standard: "cota", sn: "0x1e23dc506c1b15f286c9db84a4d12a4532660975")
    to = "ckt1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsqfrkrvjpk2e7p6e90t9sc65ahf7wjhwzqq26rfzt"
    address = create(:address, address_hash: to)
    item = create(:token_item, collection: collection, token_id: 0, owner: address)
    block = create(:block, number: 9939607)
    tx = create(:ckb_transaction, block: block,
                                  tx_hash: "0xc938c9acf95a351c2de70494b1fabc22d625fd1664741535e1058e60d454738f")
    transfer = create(:token_transfer, item: item, ckb_transaction: tx)

    Rake::Task["migration:update_cell_type"].invoke

    assert_equal "normal", transfer.reload.action
  end
end

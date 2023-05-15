require "test_helper"

class FetchCotaWorkerTest < ActiveSupport::TestCase
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
    create(:token_collection, standard: "cota", sn: "0x1e23dc506c1b15f286c9db84a4d12a4532660975")
    create(:ckb_transaction, tx_hash: "0xc938c9acf95a351c2de70494b1fabc22d625fd1664741535e1058e60d454738f")
    Sidekiq::Testing.inline!
  end

  test "should raise error" do
    CotaAggregator.any_instance.stubs(:get_aggregator_info).returns({
      "indexer_block_number" => 9939607,
      "node_block_number" => 9939607, "syncer_block_number" => 9939600, "version" => "v0.7.2" })

    assert_raises StandardError, "COTA Sync Failed!!!" do
      FetchCotaWorker.perform_inline(9939607)
    end
  end

  test "should create records" do
    CotaAggregator.any_instance.stubs(:get_aggregator_info).returns({
      "indexer_block_number" => 9939607,
      "node_block_number" => 9939607, "syncer_block_number" => 9939607, "version" => "v0.7.2" })

    FetchCotaWorker.perform_inline(9939607)

    assert_equal Address.count, 2
  end
end

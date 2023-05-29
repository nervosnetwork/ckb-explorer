require "test_helper"

module Api
  module V2
    class StatisticsControllerTest < ActionDispatch::IntegrationTest
      setup do
        pending_tx_create_at = Time.now.to_i
        confirmation_time = 10
        tx_created_at = pending_tx_create_at + confirmation_time

        block = create(:block,
                       timestamp: Faker::Time.between(from: 2.days.ago,
                                                      to: Date.today).to_i * 1000)
        tx_hash1 = "0x497277029e6335c6d5f916574dc4475ee229f3c1cce3658e7dad017a8ed580d4"
        tx_hash2 = "0xe9772bae467924e0feee85e9b7087993d38713bd8c19c954c4b68da69b4f4644"
        create :ckb_transaction, created_at: Time.at(tx_created_at),
                                 transaction_fee: 30000, bytes: 20, confirmation_time: confirmation_time, block: block, tx_hash: tx_hash1
        create :ckb_transaction, created_at: Time.at(tx_created_at),
                                 transaction_fee: 30000, bytes: 20, confirmation_time: confirmation_time, block: block, tx_hash: tx_hash2
        create :pending_transaction, transaction_fee: 30000, bytes: 20,
                                     tx_hash: tx_hash1
        create :pending_transaction, transaction_fee: 13000, bytes: 15,
                                     tx_hash: tx_hash2
      end

      test "should get transaction_fees, for committed tx" do
        VCR.use_cassette("get transaction_fees, for committed tx") do
          StatisticInfo.default.reset! :pending_transaction_fee_rates, :transaction_fee_rates
          get transaction_fees_api_v2_statistics_url,
              headers: {
                "Content-Type": "application/vnd.api+json",
                "Accept": "application/json" }
          data = JSON.parse(response.body)
          assert_equal CkbTransaction.tx_pending.count,
                       data["transaction_fee_rates"].size
          assert data["transaction_fee_rates"].first["fee_rate"] > 0
          assert data["transaction_fee_rates"].first["confirmation_time"] > 0
          assert_response :success
        end
      end

      test "should get transaction_fees, for pending tx" do
        VCR.use_cassette("get transaction_fees, for pending tx") do
          StatisticInfo.default.reset! :pending_transaction_fee_rates, :transaction_fee_rates
          get transaction_fees_api_v2_statistics_url,
              headers: {
                "Content-Type": "application/vnd.api+json",
                "Accept": "application/json" }
          data = JSON.parse(response.body)
          assert_equal CkbTransaction.tx_pending.count,
                       data["transaction_fee_rates"].size
          assert data["pending_transaction_fee_rates"].first["fee_rate"] > 0

          assert_response :success
        end
      end

      test "should get transaction_fees, for last_n_days_transaction_fee_rates" do
        VCR.use_cassette("get transaction_fees, for last_n_days_transaction_fee_rates") do
          # get today's timestamp at: 23:50:00
          current_time_stamp = Time.now.utc.end_of_day.to_i - 600
          Block.delete_all
          create :block, :with_block_hash, :with_ckb_transactions,
                 timestamp: (current_time_stamp - 3.days.to_i) * 1000,
                 total_transaction_fee: 100,
                 transactions_count: 5
          create :block, :with_block_hash, :with_ckb_transactions,
                 timestamp: (current_time_stamp - 2.days.to_i) * 1000,
                 total_transaction_fee: 100,
                 transactions_count: 2
          create :block, :with_block_hash, :with_ckb_transactions,
                 timestamp: (current_time_stamp - 1.day.to_i) * 1000,
                 total_transaction_fee: 100,
                 transactions_count: 5
          StatisticInfo.default.reset! :last_n_days_transaction_fee_rates
          get transaction_fees_api_v2_statistics_url,
              headers: {
                "Content-Type": "application/vnd.api+json",
                "Accept": "application/json" }
          data = JSON.parse(response.body)

          assert_equal 3, data["last_n_days_transaction_fee_rates"].size

          assert 1.day.ago.utc.strftime("%Y-%m-%d"),
                 data["last_n_days_transaction_fee_rates"].first["date"]
          assert_response :success
        end
      end
    end
  end
end

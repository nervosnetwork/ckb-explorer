require "test_helper"

module Api
  module V2
    class StatisticsControllerTest < ActionDispatch::IntegrationTest
      setup do

        pending_tx_create_at = Time.now.to_i
        confirmation_time = 10
        tx_created_at = pending_tx_create_at + confirmation_time

        block = create(:block)
        create :ckb_transaction, created_at: Time.at(tx_created_at), transaction_fee: 30000, bytes: 20, confirmation_time: confirmation_time, block: block
        create :ckb_transaction, created_at: Time.at(tx_created_at), transaction_fee: 30000, bytes: 20, confirmation_time: confirmation_time, block: block
        create :pool_transaction_entry, transaction_fee: 30000, bytes: 20
        create :pool_transaction_entry, transaction_fee: 13000, bytes: 15
      end

      test "should get transaction_fees, for committed tx" do
        get transaction_fees_api_v2_statistics_url
        data = JSON.parse(response.body)
        assert_equal 2, data['transaction_fee_rates'].size
        assert data['transaction_fee_rates'].first['fee_rate'] > 0
        assert data['transaction_fee_rates'].first['confirmation_time'] > 0
        assert_response :success
      end

      test "should get transaction_fees, for pending tx" do
        get transaction_fees_api_v2_statistics_url
        data = JSON.parse(response.body)
        assert_equal 2, data['pending_transaction_fee_rates'].size
        assert data['pending_transaction_fee_rates'].first['fee_rate'] > 0

        assert_response :success
      end

      test "should get transaction_fees, for last_n_days_transaction_fee_rates" do

        current_time_stamp = Time.now.beginning_of_day.to_i
        create :block, :with_block_hash, timestamp: current_time_stamp * 1000, total_transaction_fee: 100, ckb_transactions_count: 5, total_cell_capacity: 2
        create :block, :with_block_hash, timestamp: current_time_stamp * 1000, total_transaction_fee: 100, ckb_transactions_count: 2, total_cell_capacity: 2
        create :block, :with_block_hash, timestamp: (current_time_stamp - 1.day.to_i) * 1000, total_transaction_fee: 100, ckb_transactions_count: 5, total_cell_capacity: 8

        get transaction_fees_api_v2_statistics_url
        data = JSON.parse(response.body)
        assert_equal 2, data['pending_transaction_fee_rates'].size
        assert data['pending_transaction_fee_rates'].first['fee_rate'] > 0

        assert_response :success
      end
    end
  end
end

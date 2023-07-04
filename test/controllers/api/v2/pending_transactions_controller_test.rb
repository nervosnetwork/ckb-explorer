require "test_helper"

module Api
  module V2
    class PendingTransactionsControllerTest < ActionDispatch::IntegrationTest
      test "should get success code when call index" do
        valid_get api_v2_pending_transactions_url
        assert_response :success
      end

      test "should return 10 records when page and page_size are not set" do
        block = create(:block, :with_block_hash)
        create_list(:ckb_transaction, 15, tx_status: "pending", block: block)

        valid_get api_v2_pending_transactions_url

        assert_equal 10, json["meta"]["page_size"]
      end

      test "should return the corresponding transactions when page and page_size are set" do
        page = 2
        page_size = 5
        block = create(:block, :with_block_hash)
        create_list(:ckb_transaction, 15, tx_status: "pending", block: block)
        ckb_transactions = CkbTransaction.tx_pending.order(id: :desc).recent.page(page).per(page_size)

        valid_get api_v2_pending_transactions_url, params: { page: page, page_size: page_size }

        response_json = {
          data: ckb_transactions.map do |tx|
            {
              transaction_hash: tx.tx_hash,
              capacity_involved: tx.capacity_involved,
              transaction_fee: tx.transaction_fee,
              created_at: tx.created_at,
              create_timestamp: (tx.created_at.to_f * 1000).to_i
            }
          end,
          meta: {
            total: 15,
            page_size: 5
          }
        }.as_json

        assert_equal response_json, json
      end

      test "should return default order when sort param not set" do
        block = create(:block, :with_block_hash)
        create_list(:ckb_transaction, 10, tx_status: "pending", block: block)

        ckb_transactions = CkbTransaction.tx_pending.order(id: :desc)
        response_json = {
          data: ckb_transactions.map do |tx|
            {
              transaction_hash: tx.tx_hash,
              capacity_involved: tx.capacity_involved,
              transaction_fee: tx.transaction_fee,
              created_at: tx.created_at,
              create_timestamp: (tx.created_at.to_f * 1000).to_i
            }
          end,
          meta: {
            total: 10,
            page_size: 10
          }
        }.as_json

        valid_get api_v2_pending_transactions_url

        assert_equal response_json, json
      end

      test "should sorted by created_at asc when sort param is time" do
        block = create(:block, :with_block_hash)
        current_time = Time.current
        10.times do |i|
          create(:ckb_transaction, tx_status: "pending", block: block, created_at: current_time - i.hours)
        end

        ckb_transactions = CkbTransaction.tx_pending.order(created_at: :asc)
        response_json = {
          data: ckb_transactions.map do |tx|
            {
              transaction_hash: tx.tx_hash,
              capacity_involved: tx.capacity_involved,
              transaction_fee: tx.transaction_fee,
              created_at: tx.created_at,
              create_timestamp: (tx.created_at.to_f * 1000).to_i
            }
          end,
          meta: {
            total: 10,
            page_size: 10
          }
        }.as_json

        valid_get api_v2_pending_transactions_url, params: { sort: "time" }

        assert_equal response_json, json
      end

      test "should sorted by created_at asc when sort param is time.asc" do
        block = create(:block, :with_block_hash)
        current_time = Time.current
        10.times do |i|
          create(:ckb_transaction, tx_status: "pending", block: block, created_at: current_time - i.hours)
        end

        ckb_transactions = CkbTransaction.tx_pending.order(created_at: :asc)
        response_json = {
          data: ckb_transactions.map do |tx|
            {
              transaction_hash: tx.tx_hash,
              capacity_involved: tx.capacity_involved,
              transaction_fee: tx.transaction_fee,
              created_at: tx.created_at,
              create_timestamp: (tx.created_at.to_f * 1000).to_i
            }
          end,
          meta: {
            total: 10,
            page_size: 10
          }
        }.as_json

        valid_get api_v2_pending_transactions_url, params: { sort: "time.asc" }

        assert_equal response_json, json
      end

      test "should sorted by created_at asc when sort param is time.abcd" do
        block = create(:block, :with_block_hash)
        current_time = Time.current
        10.times do |i|
          create(:ckb_transaction, tx_status: "pending", block: block, created_at: current_time - i.hours)
        end

        ckb_transactions = CkbTransaction.tx_pending.order(created_at: :asc)
        response_json = {
          data: ckb_transactions.map do |tx|
            {
              transaction_hash: tx.tx_hash,
              capacity_involved: tx.capacity_involved,
              transaction_fee: tx.transaction_fee,
              created_at: tx.created_at,
              create_timestamp: (tx.created_at.to_f * 1000).to_i
            }
          end,
          meta: {
            total: 10,
            page_size: 10
          }
        }.as_json

        valid_get api_v2_pending_transactions_url, params: { sort: "time.abcd" }

        assert_equal response_json, json
      end

      test "should sorted by created_at desc when sort param is time.desc" do
        block = create(:block, :with_block_hash)
        current_time = Time.current
        10.times do |i|
          create(:ckb_transaction, tx_status: "pending", block: block, created_at: current_time - i.hours)
        end

        ckb_transactions = CkbTransaction.tx_pending.order(created_at: :desc)
        response_json = {
          data: ckb_transactions.map do |tx|
            {
              transaction_hash: tx.tx_hash,
              capacity_involved: tx.capacity_involved,
              transaction_fee: tx.transaction_fee,
              created_at: tx.created_at,
              create_timestamp: (tx.created_at.to_f * 1000).to_i
            }
          end,
          meta: {
            total: 10,
            page_size: 10
          }
        }.as_json

        valid_get api_v2_pending_transactions_url, params: { sort: "time.desc" }

        assert_equal response_json, json
      end

      test "should sorted by transaction_fee asc when sort param is fee" do
        block = create(:block, :with_block_hash)
        10.times do |i|
          create(:ckb_transaction, tx_status: "pending", block: block, transaction_fee: i)
        end

        ckb_transactions = CkbTransaction.tx_pending.order(transaction_fee: :asc)
        response_json = {
          data: ckb_transactions.map do |tx|
            {
              transaction_hash: tx.tx_hash,
              capacity_involved: tx.capacity_involved,
              transaction_fee: tx.transaction_fee,
              created_at: tx.created_at,
              create_timestamp: (tx.created_at.to_f * 1000).to_i
            }
          end,
          meta: {
            total: 10,
            page_size: 10
          }
        }.as_json

        valid_get api_v2_pending_transactions_url, params: { sort: "fee" }

        assert_equal response_json, json
      end

      test "should sorted by capacity_involved asc when sort param is capacity" do
        block = create(:block, :with_block_hash)
        10.times do |i|
          create(:ckb_transaction, tx_status: "pending", block: block, capacity_involved: i)
        end

        ckb_transactions = CkbTransaction.tx_pending.order(capacity_involved: :asc)
        response_json = {
          data: ckb_transactions.map do |tx|
            {
              transaction_hash: tx.tx_hash,
              capacity_involved: tx.capacity_involved,
              transaction_fee: tx.transaction_fee,
              created_at: tx.created_at,
              create_timestamp: (tx.created_at.to_f * 1000).to_i
            }
          end,
          meta: {
            total: 10,
            page_size: 10
          }
        }.as_json

        valid_get api_v2_pending_transactions_url, params: { sort: "capacity" }

        assert_equal response_json, json
      end

      test "should get success code when call count" do
        create_list(:ckb_transaction, 10, tx_status: "pending")
        get count_api_v2_pending_transactions_url

        assert_equal 10, json["data"]
        assert_response :success
      end
    end
  end
end

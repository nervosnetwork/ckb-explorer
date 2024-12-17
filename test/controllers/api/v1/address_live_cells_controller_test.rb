require "test_helper"

module Api
  module V1
    class AddressLiveCellsControllerTest < ActionDispatch::IntegrationTest
      test "should get success code when call show" do
        address = create(:address, :with_transactions)

        valid_get api_v1_address_live_cell_url(address.address_hash)

        assert_response :success
      end

      test "should set right content type when call show" do
        address = create(:address, :with_transactions)

        valid_get api_v1_address_live_cell_url(address.address_hash)

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should return no live cell" do
        address = create(:address, :with_udt_transactions)
        valid_get api_v1_address_live_cell_url(address.address_hash)

        assert_equal ({ "data" => [], "meta" => { "total" => 0, "page_size" => 20, "total_pages" => 0 } }), json
      end

      test "should return all live cells" do
        address = create(:address)
        block = create(:block, :with_block_hash)
        transaction = create(:ckb_transaction, block:)
        udt = create(:udt, :omiga_inscription, full_name: "CKB Fist Inscription",
                                               symbol: "CKBI", decimal: 8)
        info = udt.omiga_inscription_info
        address_lock = create(:lock_script, address_id: address.id)
        info_ts = create(:type_script,
                         args: "0xcd89d8f36593a9a82501c024c5cdc4877ca11c5b3d5831b3e78334aecb978f0d",
                         code_hash: "0x50fdea2d0030a8d0b3d69f883b471cab2a29cae6f01923f19cecac0f27fdaaa6",
                         hash_type: "type")
        create(:cell_output, address:,
                             block:,
                             ckb_transaction: transaction,
                             capacity: 1000000000000,
                             occupied_capacity: 100000000000,
                             tx_hash: transaction.tx_hash,
                             block_timestamp: block.timestamp,
                             status: "live",
                             type_hash: info.type_hash,
                             cell_index: 0,
                             lock_script_id: address_lock.id,
                             type_script_id: info_ts.id,
                             cell_type: "omiga_inscription_info",
                             data: "0x0814434b42204669737420496e736372697074696f6e04434b4249a69f54bf339dd121febe64cb0be3a2cf366a8b13ec1a5ae4bebdccb9039c7efa0040075af0750700000000000000000000e8764817000000000000000000000002")
        valid_get api_v1_address_live_cell_url(address.address_hash)
        assert_equal ({ "cell_type" => "omiga_inscription_info",
                        "tx_hash" => transaction.tx_hash,
                        "block_number" => block.number.to_s,
                        "cell_index" => 0,
                        "type_hash" => info.type_hash,
                        "data" => "0x0814434b42204669737420496e736372697074696f6e04434b4249a69f54bf339dd121febe64cb0be3a2cf366a8b13ec1a5ae4bebdccb9039c7efa0040075af0750700000000000000000000e8764817000000000000000000000002",
                        "capacity" => "1000000000000.0",
                        "occupied_capacity" => "100000000000",
                        "block_timestamp" => block.timestamp.to_s,
                        "type_script" => { "args" => "0xcd89d8f36593a9a82501c024c5cdc4877ca11c5b3d5831b3e78334aecb978f0d", "code_hash" => "0x50fdea2d0030a8d0b3d69f883b471cab2a29cae6f01923f19cecac0f27fdaaa6",
                                           "hash_type" => "type" },
                        "lock_script" => { "args" => address_lock.args, "code_hash" => address_lock.code_hash,
                                           "hash_type" => "type" },
                        "extra_info" => { "type" => "omiga_inscription", "symbol" => "CKBI", "name" => "CKB Fist Inscription", "decimal" => "8.0", "amount" => "0" } }),
                     json["data"].first["attributes"]
      end

      test "should paginate and asc sort live cells" do
        address = create(:address)
        address_lock = create(:lock_script, address_id: address.id)
        outputs = create_list(:cell_output, 10, :address_live_cells, lock_script: address_lock, address_id: address.id)
        valid_get api_v1_address_live_cell_url(address.address_hash), params: { page: 1, page_size: 5, sort: "block_timestamp.asc" }
        assert_equal outputs.first.block_timestamp.to_s, json["data"].first["attributes"]["block_timestamp"]
      end

      test "should paginate and desc sort live cells" do
        address = create(:address)
        address_lock = create(:lock_script, address_id: address.id)
        outputs = create_list(:cell_output, 10, :address_live_cells, lock_script: address_lock, address_id: address.id)
        valid_get api_v1_address_live_cell_url(address.address_hash), params: { page: 1, page_size: 5, sort: "block_timestamp.desc" }
        assert_equal outputs.last.block_timestamp.to_s, json["data"].first["attributes"]["block_timestamp"]
      end
    end
  end
end

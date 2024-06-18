require "test_helper"

module Api
  module V1
    class OmigaInscriptionsControllerTest < ActionDispatch::IntegrationTest
      test "should get success code when call show" do
        udt = create(:udt, :omiga_inscription)

        valid_get api_v1_omiga_inscription_url(udt.type_hash)

        assert_response :success
      end

      test "should return pre udt when call show" do
        udt = create(:udt, :omiga_inscription)
        udt.omiga_inscription_info.update(mint_status: :closed)
        new_udt = create(:udt, udt_type: :omiga_inscription)
        info = create(:omiga_inscription_info, udt_id: new_udt.id,
                                               mint_status: :rebase_start, pre_udt_hash: udt.omiga_inscription_info.udt_hash, udt_hash: "0x#{SecureRandom.hex(32)}")

        valid_get api_v1_omiga_inscription_url(info.type_hash, status: "closed")
        assert_equal udt.type_hash,
                     JSON.parse(response.body)["data"]["attributes"]["type_hash"]
      end

      test "should return current rebase_start udt when call show" do
        udt = create(:udt, :omiga_inscription,
                     block_timestamp: (Time.now - 10.minutes).to_i * 1000)
        udt.omiga_inscription_info.update(mint_status: :closed)
        new_udt = create(:udt, udt_type: :omiga_inscription,
                               block_timestamp: Time.now.to_i * 1000)
        info = create(:omiga_inscription_info, udt_id: new_udt.id,
                                               mint_status: :rebase_start, pre_udt_hash: udt.omiga_inscription_info.udt_hash, udt_hash: "0x#{SecureRandom.hex(32)}")

        valid_get api_v1_omiga_inscription_url(info.type_hash)
        assert_equal new_udt.type_hash,
                     JSON.parse(response.body)["data"]["attributes"]["type_hash"]
      end

      test "should set right content type when call show" do
        udt = create(:udt, :omiga_inscription)

        valid_get api_v1_omiga_inscription_url(udt.type_hash)

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        udt = create(:udt, :omiga_inscription)

        get api_v1_omiga_inscription_url(udt.type_hash),
            headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should return corresponding udt with given type hash" do
        udt = create(:udt, :omiga_inscription)

        valid_get api_v1_omiga_inscription_url(udt.type_hash)

        assert_equal UdtSerializer.new(udt).serialized_json,
                     response.body
      end

      test "should contain right keys in the serialized object when call show" do
        udt = create(:udt, :omiga_inscription)

        valid_get api_v1_omiga_inscription_url(udt.type_hash)

        response_udt = json["data"]
        assert_equal %w(
          symbol full_name total_amount addresses_count
          decimal icon_file h24_ckb_transactions_count created_at description
          published type_hash type_script issuer_address mint_status mint_limit expected_supply inscription_info_id udt_type pre_udt_hash info_type_hash operator_website email is_repeated_symbol
        ).sort,
                     response_udt["attributes"].keys.sort
      end

      test "should contain right keys in the serialized object when query info type hash" do
        udt = create(:udt, :omiga_inscription)

        valid_get api_v1_omiga_inscription_url(udt.omiga_inscription_info.type_hash)

        response_udt = json["data"]
        assert_equal %w(
          symbol full_name total_amount addresses_count
          decimal icon_file h24_ckb_transactions_count created_at description
          published type_hash type_script issuer_address mint_status mint_limit expected_supply inscription_info_id udt_type pre_udt_hash info_type_hash operator_website email is_repeated_symbol
        ).sort,
                     response_udt["attributes"].keys.sort
      end

      test "should get success code when call index" do
        valid_get api_v1_omiga_inscriptions_url
        assert_response :success
      end

      test "should set right content type when call index" do
        valid_get api_v1_omiga_inscriptions_url

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should get empty array when there are no udts" do
        valid_get api_v1_omiga_inscriptions_url

        assert_empty json["data"]
      end

      test "should return omiga_inscription udts" do
        create_list(:udt, 2, :omiga_inscription)
        valid_get api_v1_omiga_inscriptions_url

        assert_equal 2, json["data"].length
      end

      test "should return rebase_start omiga_inscription udts" do
        udt = create(:udt, :omiga_inscription)
        udt.omiga_inscription_info.update(mint_status: :closed)
        new_udt = create(:udt, udt_type: :omiga_inscription)
        create(:omiga_inscription_info, udt_id: new_udt.id,
                                        mint_status: :rebase_start, pre_udt_hash: udt.omiga_inscription_info.udt_hash, udt_hash: "0x#{SecureRandom.hex(32)}")

        valid_get api_v1_omiga_inscriptions_url

        assert_equal 1, json["data"].length
      end

      test "should sorted by mint_status asc when sort param is mint_status" do
        page = 1
        page_size = 5
        create_list(:udt, 10, :omiga_inscription)
        Udt.last.omiga_inscription_info.update(mint_status: :closed)
        udts = Udt.omiga_inscription.joins(:omiga_inscription_info).order("mint_status desc").page(page).per(page_size)

        valid_get api_v1_omiga_inscriptions_url,
                  params: { page:, page_size:, sort: "mint_status.desc" }

        options = FastJsonapi::PaginationMetaGenerator.new(request:, records: udts, page:,
                                                           page_size:).call
        response_udts = UdtSerializer.new(udts, options).serialized_json

        assert_equal response_udts, response.body
      end

      test "should get download_csv" do
        block1 = create(:block, :with_block_hash, number: 0,
                                                  timestamp: Time.now.to_i * 1000)
        tx1 = create(:ckb_transaction, block: block1,
                                       tx_hash: "0x3e89753ebca825e1504498eb18b56576d5b7eff59fe033346a10ab9e8ca359a4", block_timestamp: block1.timestamp)
        input_address1 = create(:address)
        address1_lock = create(:lock_script, address_id: input_address1.id)
        info_ts = create(:type_script,
                         args: "0xcd89d8f36593a9a82501c024c5cdc4877ca11c5b3d5831b3e78334aecb978f0d",
                         code_hash: "0x50fdea2d0030a8d0b3d69f883b471cab2a29cae6f01923f19cecac0f27fdaaa6",
                         hash_type: "type")
        info_output = create(:cell_output, ckb_transaction: tx1,
                                           block: block1, capacity: 50000000 * 10**8,
                                           tx_hash: tx1.tx_hash,
                                           cell_index: 1,
                                           address: input_address1,
                                           cell_type: "omiga_inscription_info",
                                           lock_script_id: address1_lock.id,
                                           type_script_id: info_ts.id)
        info_output.data = "0x0814434b42204669737420496e736372697074696f6e04434b42495fa66c8d5f43914f85d3083e0529931883a5b0a14282f891201069f1b50679080040075af0750700000000000000000000e8764817000000000000000000000000"
        info = create(:omiga_inscription_info,
                      code_hash: "0x50fdea2d0030a8d0b3d69f883b471cab2a29cae6f01923f19cecac0f27fdaaa6",
                      hash_type: "type",
                      args: "0xcd89d8f36593a9a82501c024c5cdc4877ca11c5b3d5831b3e78334aecb978f0d",
                      decimal: 0.8e1,
                      name: "CKB Fist Inscription",
                      symbol: "CKBI",
                      udt_hash: "0x5fa66c8d5f43914f85d3083e0529931883a5b0a14282f891201069f1b5067908",
                      expected_supply: 0.21e16,
                      mint_limit: 0.1e12,
                      mint_status: "minting",
                      udt_id: nil)
        input_address2 = create(:address)
        address2_lock = create(:lock_script, address_id: input_address2.id)

        xudt_ts = create(:type_script,
                         args: "0x9709d30fc21348ae1d28a197310a80aec3b8cdb5c93814d5e240f9fba85b76af",
                         code_hash: "0x25c29dc317811a6f6f3985a7a9ebc4838bd388d19d0feeecf0bcd60f6c0975bb",
                         hash_type: "type",
                         script_hash: "0x5fa66c8d5f43914f85d3083e0529931883a5b0a14282f891201069f1b5067908")
        block2 = create(:block, :with_block_hash, number: 1,
                                                  timestamp: Time.now.to_i * 1000)
        tx2 = create(:ckb_transaction, block: block2,
                                       tx_hash: "0xd5d38a2096c10e5d0d55def7f2b3fe58779aad831fbc9dcd594446b1f0837430")
        xudt_output = create(:cell_output, ckb_transaction: tx2,
                                           block: block2, capacity: 50000000 * 10**8,
                                           tx_hash: tx2.tx_hash,
                                           type_hash: xudt_ts.script_hash,
                                           cell_index: 1,
                                           address: input_address2,
                                           cell_type: "omiga_inscription",
                                           lock_script_id: address2_lock.id,
                                           type_script_id: xudt_ts.id)

        xudt_output.data = "0x00e87648170000000000000000000000"
        udt = create(:udt, :omiga_inscription)
        create(:udt_transaction, udt_id: udt.id, ckb_transaction_id: tx2.id)
        valid_get download_csv_api_v1_omiga_inscriptions_url(id: udt.type_hash, start_date: (Time.now - 1.minute).to_i * 1000,
                                                             end_date: Time.now.to_i * 1000)

        assert_response :success
        content = CSV.parse(response.body)
        assert_equal "0xd5d38a2096c10e5d0d55def7f2b3fe58779aad831fbc9dcd594446b1f0837430",
                     content[1][0]
      end
    end
  end
end

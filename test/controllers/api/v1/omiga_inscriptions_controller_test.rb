require "test_helper"

module Api
  module V1
    class OmigaInscriptionsControllerTest < ActionDispatch::IntegrationTest
      test "should get success code when call show" do
        udt = create(:udt, :omiga_inscription)

        valid_get api_v1_omiga_inscription_url(udt.type_hash)

        assert_response :success
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
          symbol full_name display_name uan total_amount addresses_count
          decimal icon_file h24_ckb_transactions_count created_at description
          published type_hash type_script issuer_address mint_status mint_limit expected_supply inscription_info_id
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
    end
  end
end

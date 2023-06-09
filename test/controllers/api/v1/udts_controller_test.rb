require "test_helper"

module Api
  module V1
    class UdtsControllerTest < ActionDispatch::IntegrationTest
      test "should get success code when call show" do
        udt = create(:udt, published: true)

        valid_get api_v1_udt_url(udt.type_hash)

        assert_response :success
      end

      test "should set right content type when call show" do
        udt = create(:udt)

        valid_get api_v1_udt_url(udt.type_hash)

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        udt = create(:udt)

        get api_v1_udt_url(udt.type_hash), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        udt = create(:udt)
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_udt_url(udt.type_hash), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        udt = create(:udt)

        get api_v1_udt_url(udt.type_hash), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        udt = create(:udt)
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_udt_url(udt.type_hash), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should return error object when id is not a hex start with 0x" do
        error_object = Api::V1::Exceptions::TypeHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_udt_url("9034fwefwef")

        assert_equal response_json, response.body
      end

      test "should return error object when id is a hex start with 0x but it's length is wrong" do
        error_object = Api::V1::Exceptions::TypeHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_udt_url("0x9034fwefwef")

        assert_equal response_json, response.body
      end

      test "should return error object when no records found by id" do
        error_object = Api::V1::Exceptions::UdtNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_udt_url("0x3b138b3126d10ec000417b68bc715f17e86293d6cdbcb3fd8a628ad4a0b756f6")

        assert_equal response_json, response.body
      end

      test "should return error object when target udt is not published" do
        udt = create(:udt)
        error_object = Api::V1::Exceptions::UdtNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_udt_url(udt.type_hash)

        assert_equal response_json, response.body
      end

      test "should return corresponding udt with given type hash" do
        udt = create(:udt, published: true)

        valid_get api_v1_udt_url(udt.type_hash)

        assert_equal UdtSerializer.new(udt).serialized_json, response.body
      end

      test "should contain right keys in the serialized object when call show" do
        udt = create(:udt, published: true)

        valid_get api_v1_udt_url(udt.type_hash)

        response_tx_transaction = json["data"]
        assert_equal %w(symbol full_name display_name uan total_amount addresses_count decimal icon_file h24_ckb_transactions_count created_at description published type_hash type_script issuer_address).sort, response_tx_transaction["attributes"].keys.sort
      end

      test "should get success code when call index" do
        valid_get api_v1_udts_url

        assert_response :success
      end

      test "should set right content type when call index" do
        valid_get api_v1_udts_url

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong when call index" do
        get api_v1_udts_url, headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong when call index" do
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_udts_url, headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong when call index" do
        get api_v1_udts_url, headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong when call index" do
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_udts_url, headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should get empty array when there are no udts" do
        valid_get api_v1_udts_url

        assert_empty json["data"]
      end

      test "should return udts in order of descending addresses count" do
        create(:udt, addresses_count: 1, published: true)
        create(:udt, addresses_count: 2)
        create(:udt, addresses_count: 3)

        valid_get api_v1_udts_url(addresses_count_desc: true)
        records = Udt.sudt.order(addresses_count: :desc).page(1).per(25)
        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: records, page: 1, page_size: 25).call
        expected_udts = UdtSerializer.new(records, options).serialized_json

        assert_equal expected_udts, response.body
      end


      test "should get download_csv" do
        udt = create(:udt, :with_transactions, published: true)

        valid_get download_csv_api_v1_udts_url(id: udt.type_hash, start_date: Time.now.strftime("%Y-%m-%d"), end_date: Time.now.strftime("%Y-%m-%d"))

        assert_response :success
      end
    end
  end
end

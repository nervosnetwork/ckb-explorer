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

      test "should return error object when page param is invalid" do
        error_object = Api::V1::Exceptions::PageParamError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_udts_url, params: { page: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page size param is invalid" do
        error_object = Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_udts_url, params: { page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page and page size param are invalid" do
        errors = []
        errors << Api::V1::Exceptions::PageParamError.new
        errors << Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new(errors, message: errors.first.title).serialized_json

        valid_get api_v1_udts_url, params: { page: "bbb", page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return 25 records when page and page_size are not set" do
        create_list(:udt, 30)

        valid_get api_v1_udts_url

        assert_equal 25, json["data"].size
      end

      test "should return the corresponding udts when page and page_size are set" do
        create_list(:udt, 30)
        page = 2
        page_size = 5
        udts = Udt.sudt.order(id: :desc).page(page).per(page_size)

        valid_get api_v1_udts_url, params: { page: page, page_size: page_size }

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: udts, page: page,
                                                           page_size: page_size).call
        response_udts = UdtSerializer.new(udts, options).serialized_json

        assert_equal response_udts, response.body
      end

      test "should return default order when sort param not set" do
        page = 1
        page_size = 10
        create_list(:udt, 10)
        udts = Udt.sudt.order(id: :desc).page(page).per(page_size)

       valid_get api_v1_udts_url, params: { page: page, page_size: page_size }

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: udts, page: page,
                                                           page_size: page_size).call
        response_udts = UdtSerializer.new(udts, options).serialized_json

        assert_equal response_udts, response.body
      end

      test "should sorted by h24_ckb_transactions_count asc when sort param is transactions" do
        page = 1
        page_size = 10
        10.times do |i|
          create(:udt, h24_ckb_transactions_count: i)
        end
        udts = Udt.sudt.order(h24_ckb_transactions_count: :asc).page(page).per(page_size)

       valid_get api_v1_udts_url, params: { page: page, page_size: page_size, sort: "transactions"}

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: udts, page: page,
                                                           page_size: page_size).call
        response_udts = UdtSerializer.new(udts, options).serialized_json

        assert_equal response_udts, response.body
      end

      test "should sorted by h24_ckb_transactions_count asc when sort param is transactions.asc" do
        page = 1
        page_size = 10
        10.times do |i|
          create(:udt, h24_ckb_transactions_count: i)
        end
        udts = Udt.sudt.order(h24_ckb_transactions_count: :asc).page(page).per(page_size)

       valid_get api_v1_udts_url, params: { page: page, page_size: page_size, sort: "transactions.asc"}

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: udts, page: page,
                                                           page_size: page_size).call
        response_udts = UdtSerializer.new(udts, options).serialized_json

        assert_equal response_udts, response.body
      end

      test "should sorted by h24_ckb_transactions_count asc when sort param is transactions.abcd" do
        page = 1
        page_size = 10
        10.times do |i|
          create(:udt, h24_ckb_transactions_count: i)
        end
        udts = Udt.sudt.order(h24_ckb_transactions_count: :asc).page(page).per(page_size)

       valid_get api_v1_udts_url, params: { page: page, page_size: page_size, sort: "transactions.abcd"}

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: udts, page: page,
                                                           page_size: page_size).call
        response_udts = UdtSerializer.new(udts, options).serialized_json

        assert_equal response_udts, response.body
      end

      test "should sorted by h24_ckb_transactions_count desc when sort param is transactions.desc" do
        page = 1
        page_size = 10
        10.times do |i|
          create(:udt, h24_ckb_transactions_count: i)
        end
        udts = Udt.sudt.order(h24_ckb_transactions_count: :desc).page(page).per(page_size)

       valid_get api_v1_udts_url, params: { page: page, page_size: page_size, sort: "transactions.desc"}

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: udts, page: page,
                                                           page_size: page_size).call
        response_udts = UdtSerializer.new(udts, options).serialized_json

        assert_equal response_udts, response.body
      end

      test "should sorted by block_timestamp asc when sort param is created_time" do
        page = 1
        page_size = 10
        current_time = Time.current
        10.times do |i|
          create(:udt, block_timestamp: (current_time - i.hours).to_i)
        end
        udts = Udt.sudt.order(block_timestamp: :asc).page(page).per(page_size)

       valid_get api_v1_udts_url, params: { page: page, page_size: page_size, sort: "created_time"}

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: udts, page: page,
                                                           page_size: page_size).call
        response_udts = UdtSerializer.new(udts, options).serialized_json

        assert_equal response_udts, response.body
      end

      test "should sorted by addresses_count asc when sort param is addresses_count" do
        page = 1
        page_size = 10
        10.times do |i|
          create(:udt, addresses_count: i)
        end
        udts = Udt.sudt.order(addresses_count: :asc).page(page).per(page_size)

       valid_get api_v1_udts_url, params: { page: page, page_size: page_size, sort: "addresses_count"}

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: udts, page: page,
                                                           page_size: page_size).call
        response_udts = UdtSerializer.new(udts, options).serialized_json

        assert_equal response_udts, response.body
      end

      test "should get download_csv" do
        udt = create(:udt, :with_transactions, published: true)

        valid_get download_csv_api_v1_udts_url(id: udt.type_hash, start_date: Time.now.strftime("%Y-%m-%d"), end_date: Time.now.strftime("%Y-%m-%d"))

        assert_response :success
      end
    end
  end
end

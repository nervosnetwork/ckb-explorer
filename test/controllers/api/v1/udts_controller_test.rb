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

        get api_v1_udt_url(udt.type_hash),
            headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        udt = create(:udt)
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        get api_v1_udt_url(udt.type_hash),
            headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        udt = create(:udt)

        get api_v1_udt_url(udt.type_hash),
            headers: { "Content-Type": "application/vnd.api+json",
                       "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        udt = create(:udt)
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        get api_v1_udt_url(udt.type_hash),
            headers: { "Content-Type": "application/vnd.api+json",
                       "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should return error object when id is not a hex start with 0x" do
        error_object = Api::V1::Exceptions::TypeHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        valid_get api_v1_udt_url("9034fwefwef")

        assert_equal response_json, response.body
      end

      test "should return error object when id is a hex start with 0x but it's length is wrong" do
        error_object = Api::V1::Exceptions::TypeHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        valid_get api_v1_udt_url("0x9034fwefwef")

        assert_equal response_json, response.body
      end

      test "should return error object when no records found by id" do
        error_object = Api::V1::Exceptions::UdtNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        valid_get api_v1_udt_url("0x3b138b3126d10ec000417b68bc715f17e86293d6cdbcb3fd8a628ad4a0b756f6")

        assert_equal response_json, response.body
      end

      test "should return error object when target udt is not published" do
        udt = create(:udt)
        error_object = Api::V1::Exceptions::UdtNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        valid_get api_v1_udt_url(udt.type_hash)

        assert_equal response_json, response.body
      end

      test "should return corresponding udt with given type hash" do
        udt = create(:udt, published: true, email: "abcd@sudt.com")

        valid_get api_v1_udt_url(udt.type_hash)

        assert_equal UdtSerializer.new(udt).serialized_json, response.body
        assert_equal JSON.parse(response.body)["data"]["attributes"]["email"], "ab**@******om"
      end

      test "should contain right keys in the serialized object when call show" do
        udt = create(:udt, published: true)

        valid_get api_v1_udt_url(udt.type_hash)

        response_tx_transaction = json["data"]
        assert_equal %w(
          symbol full_name total_amount addresses_count holder
          decimal icon_file h24_ckb_transactions_count created_at description
          published type_hash type_script issuer_address udt_type operator_website email
        ).sort,
                     response_tx_transaction["attributes"].keys.sort
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
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        get api_v1_udts_url, headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong when call index" do
        get api_v1_udts_url,
            headers: { "Content-Type": "application/vnd.api+json",
                       "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong when call index" do
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        get api_v1_udts_url,
            headers: { "Content-Type": "application/vnd.api+json",
                       "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should get empty array when there are no udts" do
        valid_get api_v1_udts_url

        assert_empty json["data"]
      end

      test "should return error object when page param is invalid" do
        error_object = Api::V1::Exceptions::PageParamError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        valid_get api_v1_udts_url, params: { page: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page size param is invalid" do
        error_object = Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        valid_get api_v1_udts_url, params: { page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page and page size param are invalid" do
        errors = []
        errors << Api::V1::Exceptions::PageParamError.new
        errors << Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new(errors,
                                                   message: errors.first.title).serialized_json

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

        valid_get api_v1_udts_url, params: { page:, page_size: }

        options = FastJsonapi::PaginationMetaGenerator.new(request:, records: udts, page:,
                                                           page_size:).call
        response_udts = UdtSerializer.new(udts, options).serialized_json

        assert_equal response_udts, response.body
      end

      test "should return default order when sort param not set" do
        page = 1
        page_size = 10
        create_list(:udt, 10)
        udts = Udt.sudt.order(id: :desc).page(page).per(page_size)

        valid_get api_v1_udts_url, params: { page:, page_size: }

        options = FastJsonapi::PaginationMetaGenerator.new(request:, records: udts, page:,
                                                           page_size:).call
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

        valid_get api_v1_udts_url,
                  params: { page:, page_size:, sort: "transactions" }

        options = FastJsonapi::PaginationMetaGenerator.new(request:, records: udts, page:,
                                                           page_size:).call
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

        valid_get api_v1_udts_url,
                  params: { page:, page_size:, sort: "transactions.asc" }

        options = FastJsonapi::PaginationMetaGenerator.new(request:, records: udts, page:,
                                                           page_size:).call
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

        valid_get api_v1_udts_url,
                  params: { page:, page_size:, sort: "transactions.abcd" }

        options = FastJsonapi::PaginationMetaGenerator.new(request:, records: udts, page:,
                                                           page_size:).call
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

        valid_get api_v1_udts_url,
                  params: { page:, page_size:, sort: "transactions.desc" }

        options = FastJsonapi::PaginationMetaGenerator.new(request:, records: udts, page:,
                                                           page_size:).call
        response_udts = UdtSerializer.new(udts, options).serialized_json

        assert_equal response_udts, response.body
      end

      test "should sorted by block_timestamp asc when sort param is created_time" do
        page = 1
        page_size = 10
        current_time = Time.current
        10.times do |i|
          create(:udt, block_timestamp: (current_time - i.hours).to_i * 1000)
        end
        udts = Udt.sudt.order(block_timestamp: :asc).page(page).per(page_size)

        valid_get api_v1_udts_url,
                  params: { page:, page_size:, sort: "created_time" }

        options = FastJsonapi::PaginationMetaGenerator.new(request:, records: udts, page:,
                                                           page_size:).call
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

        valid_get api_v1_udts_url,
                  params: { page:, page_size:, sort: "addresses_count" }

        options = FastJsonapi::PaginationMetaGenerator.new(request:, records: udts, page:,
                                                           page_size:).call
        response_udts = UdtSerializer.new(udts, options).serialized_json

        assert_equal response_udts, response.body
      end

      test "should get success code when call download csv" do
        udt = create(:udt, published: true)

        valid_get download_csv_api_v1_udts_url(id: udt.type_hash)

        assert_response :success
      end

      test "should respond with 415 Unsupported Media Type when call download csv Content-Type is wrong" do
        udt = create(:udt, published: true)

        get download_csv_api_v1_udts_url(id: udt.type_hash),
            headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Call download csv Content-Type is wrong" do
        udt = create(:udt, published: true)
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        get download_csv_api_v1_udts_url(id: udt.type_hash),
            headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when call download csv Accept is wrong" do
        udt = create(:udt, published: true)

        get download_csv_api_v1_udts_url(id: udt.type_hash),
            headers: {
              "Content-Type": "application/vnd.api+json",
              "Accept": "application/json",
            }

        assert_equal 406, response.status
      end

      test "should respond with error object when Call download csv Accept is wrong" do
        udt = create(:udt, published: true)
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        get download_csv_api_v1_udts_url(id: udt.type_hash),
            headers: {
              "Content-Type": "application/vnd.api+json",
              "Accept": "application/json",
            }

        assert_equal response_json, response.body
      end

      test "should return error object when call download csv id is not a type hash" do
        error_object = Api::V1::Exceptions::UdtNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        valid_get download_csv_api_v1_udts_url(id: "9034fwefwef")

        assert_equal response_json, response.body
      end

      test "should set right content type when call download csv" do
        udt = create(:udt, published: true)

        valid_get download_csv_api_v1_udts_url(id: udt.type_hash)

        assert_equal "text/csv; charset=utf-8", response.headers["Content-Type"]
      end

      test "should get download_csv" do
        udt = create(:udt, :with_transactions, published: true)
        valid_get download_csv_api_v1_udts_url(id: udt.type_hash, start_date: Time.now.to_i * 1000,
                                               end_date: Time.now.to_i * 1000)

        assert_response :success
      end

      test "should submit udt info suceessfully" do
        udt = create(:udt, published: true)

        valid_put api_v1_udt_url(udt.type_hash), params: {
          symbol: "GWK",
          full_name: "GodwokenToken on testnet_v1",
          decimal: "8",
          description: "The sUDT_ERC20_Proxy of Godwoken Test Token.",
          operator_website: "https://udt.coin",
          icon_file: "https://img.udt.img",
          email: "contact@usdt.com",
        }

        assert_response :success
        udt.reload
        assert_equal udt.symbol, "GWK"
        assert_equal udt.full_name, "GodwokenToken on testnet_v1"
        assert_equal udt.decimal, 8
        assert_equal udt.description,
                     "The sUDT_ERC20_Proxy of Godwoken Test Token."
        assert_equal udt.operator_website, "https://udt.coin"
        assert_equal udt.icon_file, "https://img.udt.img"
        assert_equal udt.email, "contact@usdt.com"
      end

      test "raise email blank error when submit udt" do
        udt = create(:udt, published: true)

        valid_put api_v1_udt_url(udt.type_hash), params: {
          symbol: "GWK",
          full_name: "GodwokenToken on testnet_v1",
          decimal: "8",
          description: "The sUDT_ERC20_Proxy of Godwoken Test Token.",
          operator_website: "https://udt.coin",
          icon_file: "https://img.udt.img",
        }

        assert_equal 400, response.status
        assert_equal [{ "title" => "UDT info parameters invalid", "detail" => "Email can't be blank", "code" => 1030, "status" => 400 }],
                     JSON.parse(response.body)
      end

      test "raise email format error when submit udt" do
        udt = create(:udt, published: true)

        valid_put api_v1_udt_url(udt.type_hash), params: {
          symbol: "GWK",
          full_name: "GodwokenToken on testnet_v1",
          decimal: "8",
          description: "The sUDT_ERC20_Proxy of Godwoken Test Token.",
          operator_website: "https://udt.coin",
          icon_file: "https://img.udt.img",
          email: "abcdefg",
        }

        assert_equal 400, response.status
        assert_equal [{ "title" => "UDT info parameters invalid", "detail" => "Validation failed: Email Not a valid email", "code" => 1030, "status" => 400 }],
                     JSON.parse(response.body)
      end

      test "raise not found error when submit udt" do
        udt = create(:udt, published: true)

        valid_put api_v1_udt_url("#{udt.type_hash}0"), params: {
          symbol: "GWK",
          full_name: "GodwokenToken on testnet_v1",
          decimal: "8",
          description: "The sUDT_ERC20_Proxy of Godwoken Test Token.",
          operator_website: "https://udt.coin",
          icon_file: "https://img.udt.img",
        }

        assert_equal 404, response.status
        assert_equal [{ "title" => "UDT Not Found", "detail" => "No UDT records found by given type hash", "code" => 1026, "status" => 404 }],
                     JSON.parse(response.body)
      end

      test "raise no udt_verification error when update udt" do
        udt = create(:udt, email: "abc@sudt.com", published: true)
        valid_put api_v1_udt_url("#{udt.type_hash}"), params: {
          symbol: "GWK",
          full_name: "GodwokenToken on testnet_v1",
          token: "123456",
        }

        assert_equal 404, response.status
        assert_equal [{ "title" => "UDT Verification Not Found", "detail" => "No UDT verification records found by given type hash", "code" => 1032, "status" => 404 }],
                     JSON.parse(response.body)
      end

      test "raise udt_verification expired error when update udt" do
        udt = create(:udt, email: "abc@sudt.com", published: true)
        create(:udt_verification, sent_at: Time.now - 11.minutes, udt:)
        valid_put api_v1_udt_url("#{udt.type_hash}"), params: {
          symbol: "GWK",
          full_name: "GodwokenToken on testnet_v1",
          token: "123456",
        }

        assert_equal 400, response.status
        assert_equal [{ "title" => "Token has expired", "detail" => "", "code" => 1034, "status" => 400 }],
                     JSON.parse(response.body)
      end

      test "raise udt_verification token not match error when update udt" do
        udt = create(:udt, email: "abc@sudt.com", published: true)
        create(:udt_verification, udt:)
        valid_put api_v1_udt_url("#{udt.type_hash}"), params: {
          symbol: "GWK",
          full_name: "GodwokenToken on testnet_v1",
          token: "123",
        }

        assert_equal 400, response.status
        assert_equal [{ "title" => "Token is not matched", "detail" => "", "code" => 1035, "status" => 400 }],
                     JSON.parse(response.body)
      end

      test "should update successfully when update udt" do
        udt = create(:udt, email: "abc@sudt.com")
        create(:udt_verification, udt:)
        valid_put api_v1_udt_url("#{udt.type_hash}"), params: {
          symbol: "GWK",
          full_name: "GodwokenToken on testnet_v1",
          token: "123456",
          email: "abcd@sudt.com",
        }

        assert_equal 200, response.status
        assert_equal "ok", JSON.parse(response.body)
        assert_equal "GWK", udt.reload.symbol
        assert_equal true, udt.reload.published
        assert_equal "abc@sudt.com", udt.reload.email
      end

      test "should not update symbol when is xudt" do
        xudt = create(:udt, :xudt)
        create(:udt_verification, udt: xudt)
        valid_put api_v1_udt_url("#{xudt.type_hash}"), params: {
          operator_website: "www.testxudt.com",
          email: "abcd@xudt.com",

        }

        assert_equal 200, response.status
        assert_equal "ok", JSON.parse(response.body)
        assert_equal "BBQ", xudt.reload.symbol
        assert_equal "www.testxudt.com", xudt.reload.operator_website
      end

      test "should not update symbol when is xudt_compatible" do
        xudt = create(:udt, udt_type: "xudt_compatible", symbol: "BBQ")
        create(:udt_verification, udt: xudt)
        valid_put api_v1_udt_url("#{xudt.type_hash}"), params: {
          operator_website: "www.testxudt.com",
          email: "abcd@xudt.com",
        }

        assert_equal 200, response.status
        assert_equal "ok", JSON.parse(response.body)
        assert_equal "BBQ", xudt.reload.symbol
        assert_equal "www.testxudt.com", xudt.reload.operator_website
      end

      test "should raise token not exist error when update udt but token not passed" do
        udt = create(:udt, email: "abc@sudt.com")
        create(:udt_verification, udt:)
        valid_put api_v1_udt_url("#{udt.type_hash}"), params: {
          symbol: "GWK",
          full_name: "GodwokenToken on testnet_v1",
        }

        assert_equal 400, response.status
        assert_equal [{ "title" => "Token is required when you update udt info", "detail" => "", "code" => 1037, "status" => 400 }],
                     JSON.parse(response.body)
      end
    end
  end
end

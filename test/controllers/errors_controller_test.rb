require "test_helper"

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test "should return 404 status code when path is not exist" do
    post "/"

    assert_response :not_found
  end

  test "should return Not Found message when path is not exist" do
    post "/oop"

    assert_response :not_found
    assert_equal "Not Found", json["message"]
  end
end

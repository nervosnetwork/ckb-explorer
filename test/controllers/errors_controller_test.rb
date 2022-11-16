require "test_helper"

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test "should return 404 status code when path is not exist" do
    begin
      post "/"
    rescue Exception => e
      assert_equal e.class, ActionController::RoutingError
      assert e.to_s.match("No route matches")
    end

  end

  test "should return Not Found message when path is not exist" do
    post "/oop"

    assert_response :not_found
    assert_equal "Not Found", json["message"]
  end
end

class ErrorsController < ActionController::API
  def routing_error
    render json: { message: "Not Found" }, status: :not_found
  end
end

class ApplicationController < ActionController::API
  before_action :check_header_info, :set_raven_context

  rescue_from Api::V1::Exceptions::Error, with: :api_error
  rescue_from ActionController::RoutingError do |exception|
    render json: { message: exception.message }, status: :not_found
  end

  def homepage
    render json: { message: "Please read more API info at https://github.com/nervosnetwork/ckb-explorer/" }
  end

  def catch_404
    raise ActionController::RoutingError.new(params[:path])
  end

  private

  def set_raven_context
    Raven.extra_context(params: params.to_unsafe_h, url: request.url) if Rails.env.production?
  end

  def api_error(error)
    render json: RequestErrorSerializer.new([error], message: error.title), status: error.status
  end

  def check_header_info
    raise Api::V1::Exceptions::InvalidContentTypeError if request.headers["Content-Type"] != "application/vnd.api+json"
    raise Api::V1::Exceptions::InvalidAcceptError if request.headers["Accept"] != "application/vnd.api+json"
  end

  def validate_pagination_params
    validator = Validations::Pagination.new(params)

    if validator.invalid?
      errors = validator.error_object[:errors]
      status = validator.error_object[:status]

      render json: errors, status: status
    end
  end
end

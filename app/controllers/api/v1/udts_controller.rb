class Api::V1::UdtsController < ApplicationController
  before_action :validate_query_params, only: :show
  before_action :validate_pagination_params, :pagination_params, only: :index

  def index
    udts = Udt.sudt.order(addresses_count: :desc).page(@page).per(@page_size)
    options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: udts, page: @page, page_size: @page_size).call
    render json: UdtSerializer.new(udts, options)
  end

  def show
    udt = Udt.find_by!(type_hash: params[:id], published: true)

    render json: UdtSerializer.new(udt)
  rescue ActiveRecord::RecordNotFound
    raise Api::V1::Exceptions::UdtNotFoundError
  end

  private

  def validate_query_params
    validator = Validations::Udt.new(params)

    if validator.invalid?
      errors = validator.error_object[:errors]
      status = validator.error_object[:status]

      render json: errors, status: status
    end
  end

  def pagination_params
    @page = params[:page] || 1
    @page_size = params[:page_size] || Udt.default_per_page
  end
end

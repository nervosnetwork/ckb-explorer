class Api::V1::UdtsController < ApplicationController
  before_action :validate_query_params, only: :show

  def index
    udts = Udt.order(addresses_count: :desc).limit(1000)
    render json: UdtSerializer.new(udts)
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
end

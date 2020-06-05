class Api::V1::UdtTransactionsController < ApplicationController
  before_action :validate_query_params
  before_action :validate_pagination_params, :pagination_params

  def show
    udt = Udt.find_by!(type_hash: params[:id], published: true)
    ckb_transactions = udt.ckb_transactions.recent.page(@page).per(@page_size)
    options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_transactions, page: @page, page_size: @page_size).call

    render json: CkbTransactionSerializer.new(ckb_transactions, options.merge({ params: { previews: true } }))
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
    @page_size = params[:page_size] || CkbTransaction.default_per_page
  end
end

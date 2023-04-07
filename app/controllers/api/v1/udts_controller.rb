require 'csv'
class Api::V1::UdtsController < ApplicationController
  before_action :validate_query_params, only: :show
  before_action :validate_pagination_params, :pagination_params, only: :index

  def index
    udts = Udt.sudt.order(addresses_count: :desc, id: :asc).page(@page).per(@page_size)
    options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: udts, page: @page, page_size: @page_size).call
    render json: UdtSerializer.new(udts, options)
  end

  def show
    udt = Udt.find_by!(type_hash: params[:id], published: true)

    render json: UdtSerializer.new(udt)
  rescue ActiveRecord::RecordNotFound
    raise Api::V1::Exceptions::UdtNotFoundError
  end

  def download_csv
    udts = Udt.order(addresses_count: :desc, id: :asc)

    file = CSV.generate do |csv|
      csv << ["TXn hash", "Blockno", "UnixTimestamp", "Method", "CKB In", "CKB OUT", "Other Cells In", "Other Cells Out", "TxnFee(CKB)", "TxnFee(USD)", "date(UTC)",
              "current CKB balance"]
      udts.each do |udt|
        udt.ckb_transactions.each_with_index do |ckb_transaction, index|
          row = [ckb_transaction.tx_hash, ckb_transaction.block_number, ckb_transaction.block_timestamp, "Transfer", "CKB In", "CKB OUT", "Other Cell In", "Other Cell OUT",
                 ckb_transaction.transaction_fee, ckb_transaction.transaction_fee, ckb_transaction.updated_at, "current CKB balance"]
          csv << row
        end
      end
    end
    send_data file, :type => 'text/csv; charset=utf-8; header=present', :disposition => "attachment;filename=ckb_transactions.csv"
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

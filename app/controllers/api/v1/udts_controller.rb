require 'csv'
class Api::V1::UdtsController < ApplicationController
  before_action :validate_query_params, only: :show
  before_action :validate_pagination_params, :pagination_params, only: :index

  def index
    udts = Udt.sudt.order(addresses_count: :desc, id: :asc).page(@page).per(@page_size).fast_page
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
    udt = Udt.find_by!(type_hash: params[:id], published: true)

    ckb_transactions = udt.ckb_transactions
    ckb_transactions = ckb_transactions.where('updated_at >= ?', params[:start_date]) if params[:start_date].present?
    ckb_transactions = ckb_transactions.where('updated_at <= ?', params[:end_date]) if params[:end_date].present?
    ckb_transactions = ckb_transactions.where('block_number >= ?', params[:start_number]) if params[:start_number].present?
    ckb_transactions = ckb_transactions.where('block_number <= ?', params[:end_number]) if params[:end_number].present?
    ckb_transactions = ckb_transactions.last(5000)

    file = CSV.generate do |csv|
      csv << ["Txn hash", "Blockno", "UnixTimestamp", "Method", "Token In", "Token OUT", "Token From", "Token To", "TxnFee(CKB)", "date(UTC)" ]

      ckb_transactions.find_each.with_index do |ckb_transaction, index|

        token_inputs = ckb_transaction.display_inputs.select { |e| e[:cell_type] == 'udt' }
        token_outputs = ckb_transaction.display_outputs.select { |e| e[:cell_type] == 'udt' }

        max = token_inputs.size > token_outputs.size ? token_inputs.size : token_outputs.size
        (1..max).each do |i|
          token_input = token_inputs[i]
          token_output = token_outputs[i]
          operation_type = "Transfer"

          row = [
            ckb_transaction.tx_hash, ckb_transaction.block_number, ckb_transaction.block_timestamp, operation_type,
            (token_input[:udt_info][:amount] / token_input[:udt_info][:decimal] to rescue '/'),
            (token_output[:udt_info][:amount] / token_input[:udt_info][:decimal] to rescue '/'),
            (token_input[:addresses_hash] rescue '/'),
            (token_output[:addresses_hash] rescue '/'),
            ckb_transaction.transaction_fee, ckb_transaction.block_timestamp
          ]
          csv << row
        end
      end
    end
    send_data file, :type => 'text/csv; charset=utf-8; header=present', :disposition => "attachment;filename=udt_transactions.csv"
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

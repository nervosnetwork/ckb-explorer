require 'csv'
class Api::V1::UdtsController < ApplicationController
  before_action :validate_query_params, only: :show
  before_action :validate_pagination_params, :pagination_params, only: :index

  def index
    udts = Udt.sudt

    params[:sort] ||= "id.desc"

    order_by, asc_or_desc = params[:sort].split('.', 2)
    order_by = case order_by
    when 'created_time' then 'block_timestamp'
    # current we don't support this in DB
    # need a new PR https://github.com/nervosnetwork/ckb-explorer/pull/1266/
    # when 'transactions' then 'h24_ckb_transactions_count'
    else order_by
    end

    head :not_found and return unless order_by.in? %w[id addresses_count block_timestamp ]

    udts = udts.order(order_by => asc_or_desc)
      .page(@page).per(@page_size).fast_page

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

    ckb_transactions = CkbTransaction.joins(:contained_udts).where("udt_transactions.udt_id = ?",  udt.id)
    ckb_transactions = ckb_transactions.where('ckb_transactions.block_timestamp >= ?', DateTime.strptime(params[:start_date], '%Y-%m-%d').to_time.to_i * 1000 ) if params[:start_date].present?
    ckb_transactions = ckb_transactions.where('ckb_transactions.block_timestamp <= ?', DateTime.strptime(params[:end_date], '%Y-%m-%d').to_time.to_i * 1000 ) if params[:end_date].present?
    ckb_transactions = ckb_transactions.where('ckb_transactions.block_number >= ?', params[:start_number]) if params[:start_number].present?
    ckb_transactions = ckb_transactions.where('ckb_transactions.block_number <= ?', params[:end_number]) if params[:end_number].present?
    ckb_transactions = ckb_transactions.order('ckb_transactions.block_timestamp desc').limit(5000)

    file = CSV.generate do |csv|
      csv << ["Txn hash", "Blockno", "UnixTimestamp", "Method", "Token In", "Token In Name", "Token OUT", "Token OUT Name", "Token From", "Token To", "TxnFee(CKB)", "date(UTC)" ]

      ckb_transactions.find_each do |ckb_transaction|

        token_inputs = ckb_transaction.display_inputs.select { |e| e[:cell_type] == 'udt' }
        token_outputs = ckb_transaction.display_outputs.select { |e| e[:cell_type] == 'udt' }

        max = token_inputs.size > token_outputs.size ? token_inputs.size : token_outputs.size
        next if max == 0

        (0 .. (max-1) ).each do |i|
          token_input = token_inputs[i]
          token_output = token_outputs[i]
          operation_type = "Transfer"
          row = [
            ckb_transaction.tx_hash, ckb_transaction.block_number, ckb_transaction.block_timestamp, operation_type,
            (token_input[:udt_info][:amount].to_d / token_input[:udt_info][:decimal] rescue '/'),
            (token_input[:udt_info][:symbol] rescue '/'),
            (token_output[:udt_info][:amount].to_d / token_input[:udt_info][:decimal] rescue '/'),
            (token_output[:udt_info][:symbol] rescue '/'),
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

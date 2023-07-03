class ExportUdtTransactionsJob < ApplicationJob
  def perform(args)
    udt = Udt.find_by!(type_hash: args[:id], published: true)
    ckb_transactions = udt.ckb_transactions

    if args[:start_date].present?
      start_date = DateTime.strptime(args[:start_date], "%Y-%m-%d").to_time.to_i * 1000
      ckb_transactions = ckb_transactions.where("block_timestamp >= ?", start_date)
    end

    if args[:end_date].present?
      end_date = DateTime.strptime(args[:end_date], "%Y-%m-%d").to_time.to_i * 1000
      ckb_transactions = ckb_transactions.where("block_timestamp <= ?", end_date)
    end

    if args[:start_number].present?
      ckb_transactions = ckb_transactions.where("block_number >= ?", args[:start_number])
    end

    if args[:end_number].present?
      ckb_transactions = ckb_transactions.where("block_number <= ?", args[:end_number])
    end

    ckb_transactions = ckb_transactions.includes(:inputs, :outputs).
      order(block_timestamp: :desc).limit(5000)

    rows = []
    ckb_transactions.find_in_batches(batch_size: 1000) do |transactions|
      transactions.each do |transaction|
        data = generate_data(transaction)
        next if data.blank?

        rows += data
      end
    end

    rows
  end

  private

  def generate_data(transaction)
    inputs = transaction.inputs.udt.sort_by(&:id)
    outputs = transaction.outputs.udt.sort_by(&:id)

    rows = []
    max = [inputs.size, outputs.size].max
    (0..max - 1).each do |i|
      input_udt_info = udt_info(inputs[i])
      output_udt_info = udt_info(outputs[i])
      operation_type = "Transfer"

      rows << [
        transaction.tx_hash,
        transaction.block_number,
        transaction.block_timestamp,
        operation_type,
        (input_udt_info[:amount].to_d / 10**input_udt_info[:decimal].to_i rescue "/"),
        (input_udt_info[:symbol] rescue "/"),
        (output_udt_info[:amount].to_d / 10**output_udt_info[:decimal].to_i rescue "/"),
        (output_udt_info[:symbol] rescue "/"),
        (inputs[i].address_hash rescue "/"),
        (outputs[i].address_hash rescue "/"),
        transaction.transaction_fee,
        Time.at((transaction.block_timestamp / 1000).to_i).in_time_zone("UTC").strftime("%Y-%m-%d %H:%M:%S")
      ]
    end

    rows
  end

  def udt_info(cell)
    return unless cell

    CkbUtils.hash_value_to_s(cell.udt_info)
  end
end

class ExportAddressTransactionsJob < ApplicationJob
  def perform(args)
    tx_ids = AccountBook.joins(:ckb_transaction).
      where(address_id: args[:address_id]).
      order(ckb_transaction_id: :asc).
      limit(5000)

    if args[:start_date].present?
      start_date = DateTime.strptime(args[:start_date], "%Y-%m-%d").to_time.to_i * 1000
      tx_ids = tx_ids.where("ckb_transactions.block_timestamp >= ?", start_date)
    end

    if args[:end_date].present?
      end_date = DateTime.strptime(args[:end_date], "%Y-%m-%d").to_time.to_i * 1000
      tx_ids = tx_ids.where("ckb_transactions.block_timestamp <= ?", end_date)
    end

    if args[:start_number].present?
      tx_ids = tx_ids.where("ckb_transactions.block_number >= ?", args[:start_number])
    end

    if args[:end_number].present?
      tx_ids = tx_ids.where("ckb_transactions.block_number <= ?", args[:end_number])
    end

    rows = []
    ckb_transactions = CkbTransaction.includes(:inputs, :outputs).
      select(:id, :tx_hash, :transaction_fee, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).
      where(id: tx_ids.pluck(:ckb_transaction_id))

    ckb_transactions.find_in_batches(batch_size: 1000, order: :desc) do |transactions|
      transactions.each do |transaction|
        rows += generate_data(transaction)
      end
    end

    rows
  end

  private

  def generate_data(transaction)
    inputs =
      if transaction.is_cellbase
        return [nil]
      else
        cell_inputs_for_display = transaction.inputs.sort_by(&:id)
        cell_inputs_for_display.map(&:capacity)
      end

    cell_outputs_for_display = transaction.outputs.sort_by(&:id)
    outputs = cell_outputs_for_display.map(&:capacity)

    rows = []
    max = [inputs.size, outputs.size].max
    (0..max - 1).each do |i|
      rows << [
        transaction.tx_hash,
        transaction.block_number,
        transaction.block_timestamp,
        "Transfer",
        (inputs[i].to_d / 1e8 rescue "/"),
        (outputs[i].to_d / 1e8 rescue "/"),
        transaction.transaction_fee,
        transaction.updated_at
      ]
    end

    rows
  end
end

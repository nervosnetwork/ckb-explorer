class ScriptSerializer
  include FastJsonapi::ObjectSerializer

  attributes :code_hash, :hash_type

  attribute :capacity_of_deployed_cells do |object, params|
    params[:deployed_cells].sum(:capacity)
  end

  attribute :capacity_of_referring_cells do |object, params|

    # it's not a rails query result, but a regular array,
    # so let's get the sum via "inject" function
    params[:referring_cells].inject(0){ |sum, x| sum + x.capacity }
  end

  attribute :deployed_cells do |object, params|
    params[:deployed_cells].map do |output_cell|
      CellOutputDataSerializer.new(output_cell).serializable_hash
    end
  end

  attribute :referring_cells do |object, params|
    params[:referring_cells].map do |output_cell|
      CellOutputDataSerializer.new(output_cell).serializable_hash
    end
  end

  attribute :transactions do |object, params|
    ckb_transactions = params[:ckb_transactions]
    ckb_transactions.map do |ckb_transaction|
      CkbTransactionSerializer.new(ckb_transaction).serializable_hash
    end
  end
end

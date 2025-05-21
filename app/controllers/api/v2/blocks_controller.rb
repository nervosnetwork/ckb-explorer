module Api::V2
  class BlocksController < BaseController
    def ckb_node_versions
      result = Block.last_7_days_ckb_node_version

      render json: {
        data: result.map do |k, v|
          {
            version: k || "others",
            blocks_count: v,
          }
        end,
      }
    end

    def by_epoch
      block = Block.where(epoch: params[:epoch_number]).order("number asc").limit(1).offset(params[:epoch_index].to_i).first
      render json: BlockSerializer.new(block)
    end
  end
end

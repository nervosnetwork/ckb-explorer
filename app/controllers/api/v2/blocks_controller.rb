module Api::V2
  class BlocksController < BaseController
    def ckb_node_versions
      from = 7.days.ago.to_i * 1000
      result = Block.last_7_days_ckb_node_version

      render json: {
        data: result.map { |k, v|
          {
            version: k,
            blocks_count: v
          }
        }
      }
    end
  end
end


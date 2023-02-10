module Api::V2
  class BlocksController < BaseController
    def ckb_node_versions
      result = Block.last_7_days_ckb_node_version

      render json: {
        data: result.map { |k, v|
          {
            version: (k || 'others'),
            blocks_count: v
          }
        }
      }
    end
  end
end


module Api::V2
  class BlocksController < BaseController
    def ckb_node_versions
      from = 7.days.ago.to_i * 1000
      sql = "select ckb_node_version, count(ckb_node_version) from blocks where timestamp >= #{from} group by ckb_node_version;"
      result = Block.where('timestamp >= ?', from.to_i * 1000).group(:ckb_node_version).sum(:ckb_node_version)
      result = ActiveRecord::Base.connection.execute(sql).values

      render json: {
        data: result
      }
    end
  end
end


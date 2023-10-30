module Api
  module V1
    class UdtQueriesController < ApplicationController
      def index
        udts = Udt.query_by_name_or_symbl(params[:q].downcase)

        render json: UdtSerializer.new(udts, { fields: { udt: [:full_name, :symbol, :type_hash, :icon_file] } })
      end
    end
  end
end

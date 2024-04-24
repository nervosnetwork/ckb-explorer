module Api
  module V1
    class SuggestQueriesController < ApplicationController
      def index
        json_response = SuggestQuery.new(params[:q], params[:filter_by]).find!

        render json: json_response
      rescue ActiveRecord::RecordNotFound
        raise Api::V1::Exceptions::SuggestQueryResultNotFoundError
      end
    end
  end
end

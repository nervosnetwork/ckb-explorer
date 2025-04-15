module Api
  module V1
    class CellOutputDataController < ApplicationController
      before_action :validate_query_params

      def show
        cell_output = CellOutput.where(id: params[:id]).take!

        raise Api::V1::Exceptions::CellOutputDataSizeExceedsLimitError if cell_output&.data_size.to_i > CellOutput::MAXIMUM_DOWNLOADABLE_SIZE

        render json: CellOutputDataSerializer.new(cell_output)
      rescue ActiveRecord::RecordNotFound
        raise Api::V1::Exceptions::CellOutputNotFoundError
      end

      private

      def validate_query_params
        validator = Validations::CellOutput.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status:
        end
      end
    end
  end
end

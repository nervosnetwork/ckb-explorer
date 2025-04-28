module Api
  module V1
    class CellInputDataController < ApplicationController
      before_action :validate_query_params

      def show
        cell_input = CellInput.find(params[:id])
        raise Api::V1::Exceptions::CellInputNotFoundError if cell_input.previous_cell_output.blank?

        cell_output = cell_input.previous_cell_output

        render json: CellOutputDataSerializer.new(cell_output)
      rescue ActiveRecord::RecordNotFound
        raise Api::V1::Exceptions::CellInputNotFoundError
      end

      private

      def validate_query_params
        validator = Validations::CellInput.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status:
        end
      end
    end
  end
end

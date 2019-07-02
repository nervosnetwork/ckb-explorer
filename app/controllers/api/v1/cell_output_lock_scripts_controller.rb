module Api
  module V1
    class CellOutputLockScriptsController < ApplicationController
      before_action :validate_query_params

      def show
        cell_output = CellOutput.cached_find(params[:id])
        lock_script = cell_output.cached_lock_script

        render json: LockScriptSerializer.new(lock_script)
      rescue ActiveRecord::RecordNotFound
        raise Api::V1::Exceptions::CellOutputNotFoundError
      end

      private

      def validate_query_params
        validator = Validations::CellOutput.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status: status
        end
      end
    end
  end
end

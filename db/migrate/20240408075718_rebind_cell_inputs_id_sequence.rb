class RebindCellInputsIdSequence < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      ALTER SEQUENCE cell_inputs_id_seq OWNED BY cell_inputs.id;
    SQL
  end
end

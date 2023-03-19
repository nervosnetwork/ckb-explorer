class ScriptTransaction < ApplicationRecord
  belongs_to :script
  belongs_to :ckb_transaction

  # run these methods:
  #    ScriptTransaction.create_initial_data
  def self.create_initial_data
    connection.execute <<-SQL
    insert into script_transactions (ckb_transaction_id, script_id)
      select distinct co.ckb_transaction_id, ls.script_id from cell_outputs co inner join lock_scripts ls on co.lock_script_id = ls.id where ls.script_id is not null
      on conflict do nothing
    SQL

    connection.execute <<-SQL
    insert into script_transactions (ckb_transaction_id, script_id)
      select distinct co.ckb_transaction_id, ts.script_id from cell_outputs co inner join type_scripts ts on co.type_script_id = ts.id where ts.script_id is not null
      on conflict do nothing
    SQL
  end
end

# == Schema Information
#
# Table name: script_transactions
#
#  id                 :bigint           not null, primary key
#  script_id          :bigint           not null
#  ckb_transaction_id :bigint           not null
#
# Indexes
#
#  index_script_transactions_on_ckb_transaction_id                (ckb_transaction_id)
#  index_script_transactions_on_ckb_transaction_id_and_script_id  (ckb_transaction_id,script_id) UNIQUE
#  index_script_transactions_on_script_id                         (script_id)
#

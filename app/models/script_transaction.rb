class ScriptTransaction < ApplicationRecord
  belongs_to :script
  belongs_to :ckb_transaction

  # run these methods:
  #    ScriptTransaction.create_initial_data
  def self.create_initial_data
    connection.execute <<-SQL
    insert into script_transactions (ckb_transaction_id, script_id)
      select co.ckb_transaction_id, ls.script_id from cell_outputs co inner join lock_scripts ls on co.lock_script_id = ls.id where ls.script_id is not null
      on conflict do nothing
    SQL

    connection.execute <<-SQL
    insert into script_transactions (ckb_transaction_id, script_id)
      select co.ckb_transaction_id, ts.script_id from cell_outputs co inner join type_scripts ts on co.type_script_id = ts.id where ts.script_id is not null
      on conflict do nothing
    SQL
  end

  def self.create_from_scripts(type_scripts_or_lock_scripts)
    ls_ids = []
    ts_ids = []
    type_scripts_or_lock_scripts.each do |s|
      if s.is_a?(TypeScript)
        ts_ids << s.id
      else
        ls_ids << s.id
      end
    end
    if ls_ids.present?
      connection.execute <<-SQL
      insert into script_transactions (ckb_transaction_id, script_id)
        select ckb_transaction_id, script_id from lock_scripts ls
        inner join (
          select co.ckb_transaction_id, co.lock_script_id
          from cell_outputs co
          where co.lock_script_id in (#{ls_ids.join(',')})
        ) as tmp on ls.id = tmp.lock_script_id
        where ls.script_id is not null
        on conflict do nothing
      SQL
    end
    if ts_ids.present?
      connection.execute <<-SQL
        insert into script_transactions (ckb_transaction_id, script_id)
        select ckb_transaction_id, script_id from type_scripts ts
        inner join (
          select co.ckb_transaction_id, co.type_script_id
          from cell_outputs co
          where co.type_script_id in (#{ts_ids.join(',')})
        ) as tmp on ts.id = tmp.type_script_id
        where ts.script_id is not null
        on conflict do nothing
      SQL
    end
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

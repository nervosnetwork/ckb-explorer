class CreateCounts < ActiveRecord::Migration[7.0]
  def change
    create_table :counts do |t|
      t.string :name, comment: 'the name of the table'
      t.integer :value, comment: 'the count value of the table'
      t.timestamps
    end

    # defined trigger and postgres functions
    # so that it is able to update the table's count automatically when insert/delete.
    raw_sql = %Q{
CREATE FUNCTION increase_ckb_transactions_count() RETURNS TRIGGER AS
$$begin
    UPDATE counts SET value = value + 1 WHERE name = 'ckb_transactions';
    RETURN NEW;
end;$$
LANGUAGE PLPGSQL VOLATILE;

CREATE TRIGGER after_insert_update_ckb_transactions_count
AFTER INSERT ON ckb_transactions
FOR EACH ROW EXECUTE PROCEDURE increase_ckb_transactions_count();

CREATE FUNCTION decrease_ckb_transactions_count() RETURNS TRIGGER AS
$$begin
    UPDATE counts SET value = value - 1 WHERE name = 'ckb_transactions';
    RETURN NEW;
end;$$
LANGUAGE PLPGSQL VOLATILE;

CREATE TRIGGER after_delete_update_ckb_transactions_count
AFTER DELETE ON ckb_transactions
FOR EACH ROW EXECUTE PROCEDURE decrease_ckb_transactions_count();
    }

    ActiveRecord::Base.connection.execute(raw_sql)

    # set the init value for this table
    Count.create! name: 'ckb_transactions', value: CkbTransaction.count

  end
end

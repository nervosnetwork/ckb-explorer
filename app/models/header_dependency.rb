# save the header_deps field (a list of hashes) in transaction raw hash
class HeaderDependency < ApplicationRecord
  belongs_to :ckb_transaction
  belongs_to :header_block, class_name: "Block", foreign_key: :header_hash, primary_key: :block_hash

  attribute :header_hash, :ckb_hash

  # migrate old witness and header deps to separate model
  def self.migrate_old(id = 0)
    CkbTransaction.where(id: id..).select(:id, :header_deps, :witnesses).find_in_batches do |txs|
      puts txs[0].id
      header_deps_attrs = []
      witnesses_attrs = []
      txs.each do |tx|
        i = -1
        if tx[:header_deps]
          header_deps_attrs +=
            CkbUtils.decode_header_deps(tx[:header_deps]).map do |h|
              i += 1
              {
                ckb_transaction_id: tx.id,
                index: i,
                header_hash: h
              }
            end
        end
        if tx[:witnesses].present?
          i = -1
          witnesses_attrs +=
            tx[:witnesses].map do |w|
              i += 1
              {
                ckb_transaction_id: tx.id,
                index: i,
                data: w
              }
            end
        end
      end

      Witness.upsert_all witnesses_attrs, unique_by: [:ckb_transaction_id, :index] if witnesses_attrs.size > 0
      if header_deps_attrs.size > 0
        HeaderDependency.upsert_all header_deps_attrs,
                                    unique_by: [:ckb_transaction_id, :index]
      end
    end
  end
end

# == Schema Information
#
# Table name: header_dependencies
#
#  id                 :bigint           not null, primary key
#  header_hash        :binary           not null
#  ckb_transaction_id :bigint           not null
#  index              :integer          not null
#
# Indexes
#
#  index_header_dependencies_on_ckb_transaction_id            (ckb_transaction_id)
#  index_header_dependencies_on_ckb_transaction_id_and_index  (ckb_transaction_id,index) UNIQUE
#

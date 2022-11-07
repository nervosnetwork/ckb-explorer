class TokenCollection < ApplicationRecord
  has_many :items, class_name: "TokenItem", foreign_key: :collection_id
  belongs_to :creator, class_name: "Address", optional: true
  belongs_to :cell, class_name: "CellOutput", optional: true
  belongs_to :type_script, optional: true
  has_many :transfers, class_name: "TokenTransfer", through: :items

  validates :sn, uniqueness: true, allow_nil: true

  def self.find_by_sn(sn)
    c = find_by sn: sn
    return c if c

    c = find_by_type_hash(sn)
    if c
      c.sn = sn
      c.save
    end
    c
  end

  def self.find_by_type_hash(type_hash)
    ts = TypeScript.find_by! script_hash: type_hash
    TokenCollection.find_by! type_script_id: ts.id
  end

  def as_json(options = {})
    {
      id: id,
      standard: standard,
      name: name,
      description: description,
      icon_url: icon_url,
      creator: creator&.address_hash || "",
      items_count: items.count,
      holders_count: items.distinct(:owner_id).count,
      type_script: type_script&.as_json
    }
  end

  before_save :update_type_script

  def update_type_script
    self.type_script_id = cell.type_script_id if cell
  end

  def update_info
    tc = self
    ts = tc.type_script
    c = ts.cell_outputs.last
    tc.cell_id = c.id
    tc.creator_id = c.address_id

    case tc.standard
    when "m_nft"
      parsed_class_data = CkbUtils.parse_token_class_data(c.data)
      tc.icon_url = parsed_class_data.renderer
      tc.name = parsed_class_data.name
      tc.description = parsed_class_data.description
    when "nrc721"
      # nrc_721_factory_cell = NrcFactoryCell.find_or_create_by(code_hash: ts.code_hash, hash_type: ts.hash_type, args: ts.args)
      parsed_factory_data = CkbUtils.parse_nrc_721_factory_data(c.data)
      tc.symbol = parsed_factory_data.symbol
      tc.name = parsed_factory_data.name
      tc.icon_url = parsed_factory_data.base_token_uri
    end

    tc.save
  end

  def update_udt_info
    items.find_each do |item|
      ts = item.type_script
      Udt.where(
        code_hash: ts.code_hash,
        hash_type: ts.hash_type,
        args: ts.args
      ).update_all(
        symbol: symbol,
        full_name: name,
        description: description,
        icon_file: icon_url
      )
    end
  end

  def self.update_cell
    where.not(type_script_id: nil).find_each do |tc|
      tc.update_info
    end
  end

  # removed the wrong token collections
  def self.remove_corrupted
    where(standard: 'nrc721').where(type_script_id: nil).or(where(creator_id: nil)).find_each do |tc|
      tc.update_info rescue nil
      
      if tc.cell.blank?
        tc.destroy
      end

      unless CkbUtils.is_nrc_721_factory_cell?(tc.cell.data)
        tc.destroy
      end
    end
  end
end

# == Schema Information
#
# Table name: token_collections
#
#  id             :bigint           not null, primary key
#  standard       :string
#  name           :string
#  description    :text
#  creator_id     :integer
#  icon_url       :string
#  items_count    :integer
#  holders_count  :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  symbol         :string
#  cell_id        :integer
#  verified       :boolean          default(FALSE)
#  type_script_id :integer
#  sn             :string
#
# Indexes
#
#  index_token_collections_on_cell_id         (cell_id)
#  index_token_collections_on_sn              (sn) UNIQUE
#  index_token_collections_on_type_script_id  (type_script_id)
#

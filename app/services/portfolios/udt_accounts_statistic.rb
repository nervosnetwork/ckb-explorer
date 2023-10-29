module Portfolios
  class UdtAccountsStatistic
    attr_reader :user

    def initialize(user)
      @user = user
    end

    def sudt_accounts(published = true)
      udt_accounts = UdtAccount.sudt.where(address_id: user.address_ids, published: published)
      grouped_accounts =
        udt_accounts.group_by(&:type_hash).transform_values do |accounts|
          total_amount = accounts.reduce(0) { |sum, account| sum + account.amount }
          {
            symbol: accounts[0].symbol,
            decimal: accounts[0].decimal.to_s,
            amount: total_amount.to_s,
            type_hash: accounts[0].type_hash,
            udt_icon_file: accounts[0].udt_icon_file,
            udt_type: accounts[0].udt_type,
            display_name: accounts[0].display_name,
            uan: accounts[0].uan
          }
        end

      grouped_accounts.values
    end

    def nft_accounts
      udt_accounts = UdtAccount.published.where(address_id: user.address_ids).
        where.not(cell_type: "sudt")
      return [] if udt_accounts.blank?

      udt_accounts.map do |udt_account|
        case udt_account.udt_type
        when "m_nft_token"
          ts = TypeScript.find_by script_hash: udt_account.type_hash
          if ts
            i = TokenItem.includes(collection: :type_script).find_by type_script_id: ts.id
            coll = i&.collection
          end
          {
            symbol: udt_account.full_name,
            decimal: udt_account.decimal.to_s,
            amount: udt_account.amount.to_s,
            type_hash: udt_account.type_hash,
            collection: {
              type_hash: coll&.type_script&.script_hash
            },
            udt_icon_file: udt_account.udt_icon_file,
            udt_type: udt_account.udt_type
          }
        when "nrc_721_token"
          udt = udt_account.udt
          factory_cell = udt_account.udt.nrc_factory_cell
          coll = factory_cell&.token_collection
          {
            symbol: factory_cell&.symbol || udt.symbol,
            amount: udt_account.nft_token_id.to_s,
            type_hash: udt_account.type_hash,
            collection: {
              type_hash: coll&.type_script&.script_hash
            },
            udt_icon_file: "#{udt_account.udt.nrc_factory_cell&.base_token_uri}/#{udt_account.nft_token_id}",
            udt_type: udt_account.udt_type
          }
        when "spore_cell"
          ts = TypeScript.where(script_hash: udt_account.type_hash).first
          if ts
            data = ts.cell_outputs.order(id: :desc).first.data
            i = TokenItem.includes(collection: :type_script).find_by type_script_id: ts.id
            coll = i&.collection
          end
          {
            symbol: udt_account.full_name,
            amount: udt_account.nft_token_id.to_s,
            type_hash: udt_account.type_hash,
            collection: {
              type_hash: coll&.type_script&.script_hash
            },
            udt_icon_file: data,
            udt_type: udt_account.udt_type
          }
        end
      end
    end
  end
end

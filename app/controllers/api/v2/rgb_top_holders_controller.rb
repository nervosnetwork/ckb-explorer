module Api
  module V2
    class RgbTopHoldersController < BaseController
      def show
        expires_in 15.minutes, public: true, stale_while_revalidate: 5.minutes, stale_if_error: 5.minutes

        udt = Udt.find_by(udt_type: %i[xudt xudt_compatible], type_hash: params[:id])
        return head :not_found unless udt

        merged_array = btc_top_holders(udt) + ckb_top_holders(udt)
        top10 = merged_array.sort_by { |item| -item[:amount].to_f }.take(10)

        render json: { data: top10 }
      end

      private

      def btc_top_holders(udt)
        result = BitcoinAddressMapping.
          joins("LEFT OUTER JOIN udt_accounts ON udt_accounts.address_id = bitcoin_address_mappings.ckb_address_id").
          where(udt_accounts: { udt_id: udt.id }).where("udt_accounts.amount > 0").
          group("bitcoin_address_mappings.bitcoin_address_id").
          select("bitcoin_address_mappings.bitcoin_address_id, SUM(udt_accounts.amount) AS total_amount").
          order("total_amount DESC").limit(10)

        result.map do |record|
          address_hash = BitcoinAddress.find_by(id: record.bitcoin_address_id).address_hash
          position_ratio = udt.total_amount.zero? ? 0 : format("%.5f", record.total_amount.to_f / udt.total_amount)
          { address_hash:, amount: record.total_amount.to_s, position_ratio: position_ratio.to_s, network: "btc" }
        end
      end

      def ckb_top_holders(udt)
        UdtAccount.joins("LEFT OUTER JOIN bitcoin_address_mappings ON udt_accounts.address_id = bitcoin_address_mappings.ckb_address_id").
          where(udt_accounts: { udt_id: udt.id}, bitcoin_address_mappings: { bitcoin_address_id: nil }).
          where("udt_accounts.amount > 0").
          order("udt_accounts.amount desc").limit(10).map do |udt_account|
          address_hash = udt_account.address.address_hash
          position_ratio = udt.total_amount.zero? ? 0 : format("%.5f", udt_account.amount.to_f / udt.total_amount)
          { address_hash:, amount: udt_account.amount.to_s, position_ratio: position_ratio.to_s, network: "ckb" }
        end
      end
    end
  end
end

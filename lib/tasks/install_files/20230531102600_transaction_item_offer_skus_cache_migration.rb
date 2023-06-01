class TransactionItemOfferSkusCacheMigration < ActiveRecord::Migration[5.1]
	def change
		change_table :aristotle_transaction_items do |t|
			t.json :sku_cache
		end

	end
end

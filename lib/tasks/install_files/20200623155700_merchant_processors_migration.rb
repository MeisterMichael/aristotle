class MerchantProcessorsMigration < ActiveRecord::Migration[5.1]
	def change

		change_table :aristotle_transaction_items do |t|
			t.string :merchant_processor, default: nil
		end

	end
end

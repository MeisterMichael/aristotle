class ExchangeRateMigration < ActiveRecord::Migration[5.1]
	def change

		change_table :aristotle_transaction_items do |t|
			t.float :exchange_rate, default: 1.0
		end

	end
end

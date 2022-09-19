class FirstTransactionMigration < ActiveRecord::Migration[5.1]
	def change

		change_table :aristotle_orders do |t|
			t.text 			:tags, default: [], array: true
			t.index 		["tags"], using: :gin
		end

		change_table :aristotle_transaction_items do |t|
			t.belongs_to :order
			t.text 			:tags, default: [], array: true
			t.index 		["tags"], using: :gin
		end

		change_table :aristotle_transaction_skus do |t|
			t.belongs_to :order
			t.text 			:tags, default: [], array: true
			t.index 		["tags"], using: :gin
		end

	end
end

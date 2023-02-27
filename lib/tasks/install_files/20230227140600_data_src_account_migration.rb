class DataSrcAccountMigration < ActiveRecord::Migration[5.1]
	def change

		change_table :aristotle_transaction_items do |t|
			t.string :data_src_account, default: nil
			t.index [:data_src_account, :data_src], name: 'index_aristotle_transaction_items_on_data_src_accnt'
		end

		change_table :aristotle_transaction_skus do |t|
			t.string :data_src_account, default: nil
			t.index [:data_src_account, :data_src], name: 'index_aristotle_transaction_skus_on_data_src_accnt'
		end

		change_table :aristotle_orders do |t|
			t.string :data_src_account, default: nil
			t.index [:data_src_account, :data_src], name: 'index_aristotle_orders_on_data_src_accnt'
		end

	end
end

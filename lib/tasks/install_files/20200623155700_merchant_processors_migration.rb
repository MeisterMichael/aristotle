class MerchantProcessorsMigration < ActiveRecord::Migration[5.1]
	def change

		change_table :aristotle_transaction_items do |t|
			t.string :merchant_processor, default: nil
			t.belongs_to :warehouse
		end

		create_table :aristotle_warehouses do |t|
			t.string			:name
			t.string			:data_src
			t.string			:src_warehouse_id
			t.timestamps
			t.index [:src_warehouse_id,:data_src]
		end

	end
end

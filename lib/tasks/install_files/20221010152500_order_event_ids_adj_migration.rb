class OrderEventIdsAdjMigration < ActiveRecord::Migration[5.1]
	def change

		rename_column :aristotle_transaction_items, :event_client_id, :src_event_client_id
		rename_column :aristotle_transaction_items, :event_id, :src_event_id
		change_table :aristotle_transaction_items do |t|
			t.integer :event_client_purchase_index, default: 1
			t.index [:event_client_purchase_index, :src_event_client_id], name: 'index_aristotle_transaction_items_on_purchase_index'
		end

		rename_column :aristotle_transaction_skus, :event_client_id, :src_event_client_id
		rename_column :aristotle_transaction_skus, :event_id, :src_event_id
		change_table :aristotle_transaction_skus do |t|
			t.integer :event_client_purchase_index, default: 1
			t.index [:event_client_purchase_index, :src_event_client_id], name: 'index_aristotle_transaction_skus_on_purchase_index'
		end

		rename_column :aristotle_orders, :event_client_id, :src_event_client_id
		rename_column :aristotle_orders, :event_id, :src_event_id
		change_table :aristotle_orders do |t|
			t.integer :event_client_purchase_index, default: 1
			t.index [:event_client_purchase_index, :src_event_client_id], name: 'index_aristotle_orders_on_purchase_index'
		end

	end
end

class OrderEventIdsMigration < ActiveRecord::Migration[5.1]
	def change

		change_table :aristotle_transaction_items do |t|
			t.string :event_data_src, default: nil
			t.string :event_client_id, default: nil
			t.string :event_id, default: nil
		end

		change_table :aristotle_transaction_skus do |t|
			t.string :event_data_src, default: nil
			t.string :event_client_id, default: nil
			t.string :event_id, default: nil
		end

		change_table :aristotle_orders do |t|
			t.string :event_data_src, default: nil
			t.string :event_client_id, default: nil
			t.string :event_id, default: nil
		end

		change_table :aristotle_subscriptions do |t|
			t.string :event_data_src, default: nil
			t.string :event_client_id, default: nil
			t.string :event_id, default: nil
		end

	end
end

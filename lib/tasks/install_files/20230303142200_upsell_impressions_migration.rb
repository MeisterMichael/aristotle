class UpsellImpressionsMigration < ActiveRecord::Migration[5.1]
	def change
		create_table :aristotle_upsell_impressions do |t|

			t.belongs_to :customer
			t.belongs_to :from_offer
			t.belongs_to :from_product
			t.belongs_to :upsell_offer
			t.belongs_to :upsell_product
			t.belongs_to :impression_event
			t.belongs_to :purchase_event
			t.belongs_to :accepted_event
			t.belongs_to :order

			t.string :event_data_src
			t.bigint :src_client_id
			t.datetime :src_created_at
			t.datetime :accepted_at
			t.datetime :purchased_at
			t.string :order_data_src
			t.string :src_order_id

			t.timestamps
		end

	end
end

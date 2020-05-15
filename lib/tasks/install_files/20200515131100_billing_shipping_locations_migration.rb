class BillingShippingLocationsMigration < ActiveRecord::Migration[5.1]
	def change

		change_table :aristotle_transaction_items do |t|
			t.belongs_to :billing_location
			t.belongs_to :shipping_location
		end

		change_table :aristotle_orders do |t|
			t.belongs_to :billing_location
			t.belongs_to :shipping_location
		end

		change_table :aristotle_subscriptions do |t|
			t.belongs_to :billing_location
			t.belongs_to :shipping_location
		end

		change_table :aristotle_coupon_uses do |t|
			t.belongs_to :billing_location
			t.belongs_to :shipping_location
		end

		change_table :aristotle_customers do |t|
			t.belongs_to :billing_location
			t.belongs_to :shipping_location
		end

		change_table :aristotle_wholesale_clients do |t|
			t.belongs_to :billing_location
			t.belongs_to :shipping_location
		end

	end
end

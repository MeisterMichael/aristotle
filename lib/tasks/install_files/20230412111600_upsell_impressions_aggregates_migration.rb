class UpsellImpressionsAggregatesMigration < ActiveRecord::Migration[5.1]
	def change
		change_table :aristotle_upsell_impressions do |t|

			t.belongs_to :subscription

			t.integer :order_upsell_count

			t.integer :order_charge_sub_total
			t.integer :order_refund_sub_total
			t.integer :offer_charge_sub_total
			t.integer :offer_refund_sub_total
			t.integer :order_ltv_charge_sub_total
			t.integer :order_ltv_refund_sub_total
			t.integer :offer_ltv_charge_sub_total
			t.integer :offer_ltv_refund_sub_total

		end

	end
end

class CouponIndecesMigration < ActiveRecord::Migration[5.1]
	def change

		change_table :aristotle_coupons do |t|
			t.index 		["code"]
		end

		change_table :aristotle_coupon_uses do |t|
			t.index 		["used_at"]
			t.index 		["data_src"]
			t.index 		["src_order_id","data_src"], name: 'index_aristotle_coupon_uses_on_src_order_id'
			t.index 		["src_transaction_id","src_order_id","data_src"], name: 'index_aristotle_coupon_uses_on_src_trans_id'
		end

	end
end

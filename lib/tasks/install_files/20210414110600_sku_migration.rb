class SkuMigration < ActiveRecord::Migration[5.1]
	def change

		create_table :aristotle_skus do |t|
			t.string			:name
			t.string			:code
			t.string			:data_src
			t.string			:src_sku_id
			t.timestamps
			t.index [:src_sku_id,:data_src]
			t.index [:code]
		end

		create_table :aristotle_transaction_skus do |t|
			t.integer "status", default: 0
			t.datetime "src_created_at"
			t.datetime "transacted_at"
			t.datetime "canceled_at"
			t.datetime "failed_at"
			t.datetime "pending_at"
			t.datetime "pre_ordered_at"
			t.datetime "on_hold_at"
			t.datetime "processing_at"
			t.datetime "completed_at"
			t.datetime "refunded_at"
			t.integer "customer_id"
			t.integer "location_id"
			t.integer "subscription_id"
			t.integer "offer_id"
			t.integer "product_id"
			t.integer "channel_partner_id"
			t.string "src_subscription_id"
			t.string "src_order_id"
			t.string "src_transaction_id"
			t.integer "transaction_type", default: 1
			t.string "campaign"
			t.string "source"
			t.integer "sku_value"
			t.integer "amount"
			t.integer "misc_discount"
			t.integer "coupon_discount"
			t.integer "total_discount"
			t.integer "sub_total"
			t.integer "shipping"
			t.integer "shipping_tax"
			t.integer "tax"
			t.integer "adjustment"
			t.integer "total"
			t.integer "commission"
			t.datetime "created_at"
			t.datetime "updated_at"
			t.string "data_src", default: "woocommerce"
			t.string "src_order_item_id"
			t.string "src_order_label"
			t.integer "payment_type", default: 0
			t.datetime "commission_captured_at"
			t.integer "klaviyo_marketing_spend_id"
			t.string "currency", default: "USD"
			t.integer "currency_total"
			t.bigint "wholesale_client_id"
			t.string "src_line_item_id"
			t.integer "offer_type", default: 0
			t.integer "subscription_interval", default: 1
			t.float "exchange_rate"
			t.bigint "billing_location_id"
			t.bigint "shipping_location_id"
			t.string "merchant_processor"
			t.bigint "warehouse_id"
			t.bigint "sku_id"
			t.index ["billing_location_id"], name: "index_aristotle_transaction_skus_on_billing_location_id"
			t.index ["campaign"], name: "index_aristotle_transaction_skus_on_campaign"
			t.index ["channel_partner_id"], name: "index_aristotle_transaction_skus_on_channel_partner_id"
			t.index ["completed_at"], name: "index_aristotle_transaction_skus_on_completed_at"
			t.index ["customer_id"], name: "index_aristotle_transaction_skus_on_customer_id"
			t.index ["data_src"], name: "index_aristotle_transaction_skus_on_data_src"
			t.index ["location_id"], name: "index_aristotle_transaction_skus_on_location_id"
			t.index ["offer_id"], name: "index_aristotle_transaction_skus_on_offer_id"
			t.index ["offer_type"], name: "index_aristotle_transaction_skus_on_offer_type"
			t.index ["product_id"], name: "index_aristotle_transaction_skus_on_product_id"
			t.index ["shipping_location_id"], name: "index_aristotle_transaction_skus_on_shipping_location_id"
			t.index ["sku_id"], name: "index_aristotle_transaction_skus_on_sku_id"
			t.index ["source"], name: "index_aristotle_transaction_skus_on_source"
			t.index ["src_created_at", "customer_id"], name: "aristotle_transaction_skus_src_c_at_customer_id"
			t.index ["src_created_at", "product_id", "channel_partner_id", "customer_id"], name: "aristotle_transaction_skus_src_c_at_pid_cp_id"
			t.index ["src_created_at", "product_id", "channel_partner_id", "transaction_type"], name: "aristotle_transaction_skus_src_c_at_pid_cp_id_ttype"
			t.index ["src_created_at", "product_id", "customer_id"], name: "aristotle_transaction_skus_src_c_at_pid_cust_id"
			t.index ["src_created_at"], name: "index_aristotle_transaction_skus_on_src_created_at"
			t.index ["src_order_id"], name: "index_aristotle_transaction_skus_on_src_order_id"
			t.index ["src_order_label", "data_src"], name: "index_transaction_skus_on_srcolabel_datasrc"
			t.index ["src_transaction_id"], name: "index_aristotle_transaction_skus_on_src_transaction_id"
			t.index ["subscription_id", "transaction_type", "completed_at", "src_created_at", "payment_type"], name: "index_transaction_skus_on_sub_and_ttype_compat_screatat_ptype"
			t.index ["subscription_id"], name: "index_aristotle_transaction_skus_on_subscription_id"
			t.index ["subscription_interval"], name: "index_aristotle_transaction_skus_on_subscription_interval"
			t.index ["transacted_at"], name: "index_aristotle_transaction_skus_on_transacted_at"
			t.index ["transaction_type"], name: "index_aristotle_transaction_skus_on_transaction_type"
			t.index ["warehouse_id"], name: "index_aristotle_transaction_skus_on_warehouse_id"
			t.index ["wholesale_client_id"], name: "index_aristotle_transaction_skus_on_wholesale_client_id"
		end

	end
end

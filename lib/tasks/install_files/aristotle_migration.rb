class AristotleMigration < ActiveRecord::Migration[5.1]

	def change

		# These are extensions that must be enabled in order to support this database
		enable_extension "plpgsql"
		enable_extension "hstore"

		create_table "aristotle_channel_partners", id: :serial, force: :cascade do |t|
			t.string "code"
			t.string "company_name"
			t.string "name"
			t.string "login"
			t.string "email"
			t.string "description"
			t.integer "status"
			t.float "score"
			t.datetime "created_at"
			t.datetime "updated_at"
			t.integer "parent_id"
			t.string "data_src", default: nil
			t.string "src_channel_partner_id"
			t.string "woocommerce_channel_partner_id"
			t.string "refersion_channel_partner_id"
			t.integer "user_id"
			t.boolean "deny_recurring_commissions", default: false
			t.float "commission_rate"
			t.float "recruiter_commission_rate"
		end

		create_table "aristotle_coupon_uses", id: :serial, force: :cascade do |t|
			t.datetime "used_at"
			t.integer "coupon_id"
			t.integer "customer_id"
			t.integer "location_id"
			t.integer "channel_partner_id"
			t.string "src_order_id"
			t.string "src_transaction_id"
			t.string "campaign"
			t.string "source"
			t.integer "amount"
			t.integer "tax"
			t.integer "shipping"
			t.integer "total"
			t.datetime "created_at"
			t.datetime "updated_at"
			t.string "data_src", default: nil
			t.string "currency", default: "USD"
			t.integer "currency_total"
			t.string "coupon_use_src_id"
		end

		create_table "aristotle_coupons", id: :serial, force: :cascade do |t|
			t.string "src_coupon_id"
			t.string "code"
			t.string "name"
			t.string "description"
			t.integer "discount_type"
			t.integer "discount_amount"
			t.boolean "individual_use"
			t.boolean "free_shipping"
			t.datetime "expires_at"
			t.integer "channel_partner_id"
			t.datetime "created_at"
			t.datetime "updated_at"
			t.string "data_src", default: nil
		end

		create_table "aristotle_channel_partners", id: :serial, force: :cascade do |t|
			t.string "code"
			t.string "company_name"
			t.string "name"
			t.string "login"
			t.string "email"
			t.string "description"
			t.integer "status"
			t.float "score"
			t.datetime "created_at"
			t.datetime "updated_at"
			t.integer "parent_id"
			t.string "data_src", default: nil
			t.string "src_channel_partner_id"
			t.string "woocommerce_channel_partner_id"
			t.string "refersion_channel_partner_id"
			t.integer "user_id"
			t.boolean "deny_recurring_commissions", default: false
			t.float "commission_rate"
			t.float "recruiter_commission_rate"
		end

		create_table "aristotle_currency_exchanges", id: :serial, force: :cascade do |t|
			t.string "from_currency"
			t.string "to_currency"
			t.float "rate"
			t.datetime "created_at"
			t.datetime "updated_at"
		end

		create_table "aristotle_customers", id: :serial, force: :cascade do |t|
			t.string "name"
			t.string "login"
			t.string "email"
			t.integer "status"
			t.integer "location_id"
			t.datetime "src_created_at"
			t.datetime "created_at"
			t.datetime "updated_at"
			t.string "data_src", default: nil
			t.string "src_customer_id"
			t.string "shopify_customer_id"
			t.string "klaviyo_id"
			t.datetime "opted_out_at"
			t.datetime "opted_in_at"
		end

		create_table "aristotle_email_campaigns", id: :serial, force: :cascade do |t|
			t.string "list_name"
			t.string "list_type"
			t.string "list_id"
			t.string "flow_name"
			t.string "flow_id"
			t.string "campaign_name"
			t.string "campaign_id"
			t.datetime "created_at"
			t.datetime "updated_at"
			t.index ["campaign_id", "flow_id"], name: "index_email_campaigns_on_campaign_id_and_flow_id"
		end

		create_table "aristotle_events", force: :cascade do |t|
			t.string "data_src"
			t.bigint "src_event_id"
			t.bigint "src_user_id"
			t.bigint "src_client_id"
			t.string "src_target_obj_type"
			t.bigint "src_target_obj_id"
			t.bigint "channel_partner_id"
			t.bigint "coupon_id"
			t.bigint "customer_id"
			t.bigint "email_campaign_id"
			t.bigint "location_id"
			t.bigint "offer_id"
			t.bigint "order_id"
			t.bigint "product_id"
			t.bigint "wholesale_client_id"
			t.string "name"
			t.string "category"
			t.text "content"
			t.integer "value", default: 0
			t.string "ip"
			t.string "user_agent"
			t.string "campaign_source"
			t.string "campaign_medium"
			t.string "campaign_name"
			t.string "campaign_term"
			t.string "campaign_content"
			t.integer "campaign_cost"
			t.string "partner_source"
			t.string "partner_id"
			t.string "referrer_url"
			t.string "referrer_host"
			t.boolean "referrer_host_external"
			t.string "referrer_path"
			t.string "page_url"
			t.string "page_host"
			t.string "page_path"
			t.string "page_name"
			t.hstore "properties"
			t.string "page_params"
			t.string "referrer_params"
			t.bigint "client_user_id"
			t.string "client_uuid"
			t.string "client_ip"
			t.string "client_user_agent"
			t.string "client_country"
			t.string "client_state"
			t.string "client_city"
			t.string "client_referrer_url"
			t.string "client_referrer_host"
			t.string "client_referrer_path"
			t.string "client_lander_url"
			t.string "client_lander_host"
			t.string "client_lander_path"
			t.string "client_campaign_source"
			t.string "client_campaign_medium"
			t.string "client_campaign_term"
			t.string "client_campaign_content"
			t.string "client_campaign_name"
			t.integer "client_campaign_cost"
			t.string "client_partner_source"
			t.string "client_partner_id"
			t.boolean "client_is_bot"
			t.string "client_device_type"
			t.string "client_device_family"
			t.string "client_device_brand"
			t.string "client_device_model"
			t.string "client_os_name"
			t.string "client_os_version"
			t.string "client_browser_family"
			t.string "client_browser_version"
			t.hstore "client_properties"
			t.string "client_referrer_params"
			t.string "client_lander_params"
			t.datetime "event_created_at"
			t.datetime "event_updated_at"
			t.datetime "client_created_at"
			t.datetime "client_updated_at"
			t.datetime "created_at", null: false
			t.datetime "updated_at", null: false
			t.index ["data_src", "src_event_id", "event_created_at"], name: "index_events_on_data_src_and_src_event_id_and_event_created_at"
		end

		create_table "aristotle_locations", id: :serial, force: :cascade do |t|
			t.string "city"
			t.string "state_code"
			t.string "zip"
			t.string "country_code"
			t.datetime "created_at"
			t.datetime "updated_at"
			t.string "data_src", default: nil
		end

		create_table "aristotle_marketing_spends", id: :serial, force: :cascade do |t|
			t.string "source"
			t.string "medium"
			t.string "content"
			t.string "term"
			t.string "campaign"
			t.string "data_src"
			t.string "src_account_id"
			t.string "src_account_name"
			t.string "src_campaign_id"
			t.integer "click_count"
			t.integer "click_uniq_count"
			t.integer "purchase_count"
			t.integer "purchase_uniq_count"
			t.integer "purchase_value"
			t.integer "spend"
			t.datetime "start_at"
			t.datetime "end_at"
			t.datetime "created_at"
			t.datetime "updated_at"
			t.integer "purpose", default: 0
			t.string "research_type"
			t.string "campaign_id"
			t.integer "email_campaign_id"
			t.integer "sent_count"
			t.integer "open_count"
			t.integer "open_uniq_count"
			t.index ["data_src", "start_at", "end_at"], name: "index_marketing_spends_on_data_src_and_start_at_and_end_at"
			t.index ["medium", "email_campaign_id", "campaign_id"], name: "index_marketing_spends_on_medm_and_emailcampgnid_and_campgnid"
		end

		create_table "aristotle_offers", id: :serial, force: :cascade do |t|
			t.integer "product_id"
			t.string "name"
			t.string "sku"
			t.string "description"
			t.integer "status"
			t.integer "offer_type", default: 0
			t.datetime "created_at"
			t.datetime "updated_at"
			t.string "data_src", default: nil
		end

		create_table "aristotle_orders", id: :serial, force: :cascade do |t|
			t.integer "channel_partner_id"
			t.integer "customer_id"
			t.integer "location_id"
			t.string "campaign"
			t.string "source"
			t.string "src_subscription_id"
			t.string "src_order_id"
			t.integer "status"
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
			t.datetime "created_at"
			t.datetime "updated_at"
			t.string "data_src", default: nil
			t.string "src_order_label"
			t.bigint "wholesale_client_id"
			t.index ["src_order_label", "data_src"], name: "index_orders_on_src_order_label_and_data_src"
			t.index ["wholesale_client_id"], name: "index_orders_on_wholesale_client_id"
		end

		create_table "aristotle_product_aliases", id: :serial, force: :cascade do |t|
			t.bigint "product_id"
			t.string "src_product_id"
			t.string "sku"
			t.datetime "created_at"
			t.datetime "updated_at"
			t.string "data_src", default: nil
		end

		create_table "aristotle_products", id: :serial, force: :cascade do |t|
			t.string "name"
			t.string "sku"
			t.string "description"
			t.integer "status"
			t.string "src_product_id"
			t.datetime "created_at"
			t.datetime "updated_at"
			t.string "data_src", default: nil
		end

		create_table "aristotle_subscriptions", id: :serial, force: :cascade do |t|
			t.integer "customer_id"
			t.integer "location_id"
			t.integer "transaction_item_id"
			t.integer "offer_id"
			t.integer "product_id"
			t.integer "channel_partner_id"
			t.datetime "src_created_at"
			t.string "src_subscription_id"
			t.string "src_order_id"
			t.string "campaign"
			t.string "source"
			t.integer "quantity"
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
			t.integer "recurrance_count", default: 0
			t.integer "max_recurrance_count", default: 0
			t.integer "status", default: 1
			t.integer "removed", default: 0
			t.boolean "cancel_at_period_end"
			t.datetime "canceled_at"
			t.datetime "current_period_end"
			t.datetime "current_period_start"
			t.datetime "on_hold_at"
			t.datetime "ended_at"
			t.datetime "start_at"
			t.datetime "effective_ended_at"
			t.datetime "trial_end_at"
			t.datetime "trail_start_at"
			t.datetime "created_at"
			t.datetime "updated_at"
			t.string "data_src", default: nil
			t.string "recharge_subscription_id"
			t.boolean "deny_recurring_commissions", default: false
			t.integer "payment_type", default: 0
			t.string "currency", default: "USD"
			t.integer "currency_total"
			t.bigint "wholesale_client_id"
			t.index ["amount"], name: "index_subscriptions_on_amount"
			t.index ["channel_partner_id"], name: "index_subscriptions_on_channel_partner_id"
			t.index ["customer_id"], name: "index_subscriptions_on_customer_id"
			t.index ["data_src"], name: "index_subscriptions_on_data_src"
			t.index ["location_id"], name: "index_subscriptions_on_location_id"
			t.index ["offer_id"], name: "index_subscriptions_on_offer_id"
			t.index ["payment_type"], name: "index_subscriptions_on_payment_type"
			t.index ["product_id"], name: "index_subscriptions_on_product_id"
			t.index ["src_created_at"], name: "index_subscriptions_on_src_created_at"
			t.index ["start_at", "payment_type", "product_id", "channel_partner_id"], name: "index_subscriptions_on_start_and_ptype_and_pid_and_cp"
			t.index ["start_at"], name: "index_subscriptions_on_start_at"
			t.index ["transaction_item_id"], name: "index_subscriptions_on_transaction_item_id"
			t.index ["wholesale_client_id"], name: "index_subscriptions_on_wholesale_client_id"
		end

		create_table "aristotle_transaction_items", id: :serial, force: :cascade do |t|
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
			t.string "data_src", default: nil
			t.string "src_line_item_id"
			t.string "src_order_label"
			t.integer "payment_type", default: 0
			t.datetime "commission_captured_at"
			t.integer "klaviyo_marketing_spend_id"
			t.string "currency", default: "USD"
			t.integer "currency_total"
			t.bigint "wholesale_client_id"
			t.index ["campaign"], name: "index_transaction_items_on_campaign"
			t.index ["channel_partner_id"], name: "index_transaction_items_on_channel_partner_id"
			t.index ["completed_at"], name: "index_transaction_items_on_completed_at"
			t.index ["customer_id"], name: "index_transaction_items_on_customer_id"
			t.index ["data_src"], name: "index_transaction_items_on_data_src"
			t.index ["location_id"], name: "index_transaction_items_on_location_id"
			t.index ["offer_id"], name: "index_transaction_items_on_offer_id"
			t.index ["product_id"], name: "index_transaction_items_on_product_id"
			t.index ["source"], name: "index_transaction_items_on_source"
			t.index ["src_created_at"], name: "index_transaction_items_on_src_created_at"
			t.index ["src_order_id"], name: "index_transaction_items_on_src_order_id"
			t.index ["src_order_label", "data_src"], name: "index_transaction_items_on_src_order_label_and_data_src"
			t.index ["src_transaction_id"], name: "index_transaction_items_on_src_transaction_id"
			t.index ["subscription_id", "transaction_type", "completed_at", "src_created_at", "payment_type"], name: "index_transaction_items_on_sub_and_ttype_compat_screatat_ptype"
			t.index ["subscription_id"], name: "index_transaction_items_on_subscription_id"
			t.index ["transacted_at"], name: "index_transaction_items_on_transacted_at"
			t.index ["transaction_type"], name: "index_transaction_items_on_transaction_type"
			t.index ["wholesale_client_id"], name: "index_transaction_items_on_wholesale_client_id"
		end

		create_table "aristotle_wholesale_clients", force: :cascade do |t|
			t.string "name"
			t.string "email"
			t.string "src_wholesale_client_id"
			t.string "data_src"
			t.datetime "src_created_at"
			t.datetime "created_at", null: false
			t.datetime "updated_at", null: false
			t.bigint "customer_id"
			t.bigint "location_id"
		end

	end

end

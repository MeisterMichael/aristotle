module Aristotle
	class BazaarEtl < EcomEtl

		ORDER_ITEM_TYPE_PROD = 1
		ORDER_ITEM_TYPE_TAX = 2
		ORDER_ITEM_TYPE_SHIPPING = 3
		ORDER_ITEM_TYPE_DISCOUNT = 4

		SUBSCRIPTION_STATUS_CANCELED = -1
		SUBSCRIPTION_STATUS_FAILED = 0
		SUBSCRIPTION_STATUS_ACTIVE = 1

		DISCOUNT_ITEM_ALL_ORDER_ITEM_TYPES = 0
		DISCOUNT_ITEM_SHIPPING_ORDER_ITEM_TYPE = 3

		DISCOUNT_TYPE_MAP = { '1' => 'percent', '2' => 'fixed_cart' }

		ORDER_STATUS_ACTIVE = 2

		def initialize( args = {} )
			@data_src = args[:data_src] || 'swell'
			@connection_options = args[:connection]
			# @connection_options ||= ENV['DEFAULT_SWELL_ECOM_ETL_DATABASE_URL']
			@connection_options ||= {
				adapter: 'postgresql',
				encoding: 'unicode',
				database: 'nhc_trial_store',
				password: ENV['DEV_DATABASE_PASSWORD'],
				port: ( ENV["DEV_DATABASE_PORT"] || '5432' ),
				host: ( ENV["DEV_DATABASE_HOST"] || 'localhost' ),
				username: ( ENV["DEV_DATABASE_USERNAME"] || 'postgres' ),
			}

			@order_type = args[:order_type]
			@order_source = args[:order_source]
		end

		def connection
			# @connection ||= ActiveRecord::Base.establish_connection(@connection_options).connection
			if @connection_options.is_a? Hash
				@connection ||= PG.connect( dbname: @connection_options[:database], password: @connection_options[:password], port: @connection_options[:port], host: @connection_options[:host], user: @connection_options[:username] )
			elsif @connection_options.is_a? String
				@connection ||= PG.connect( @connection_options )
			end
		end

		def data_src
			@data_src
		end

		def exec_query( query, args = {} )
			query = ActiveRecord::Base.__send__(:sanitize_sql, [query, args])
			connection.exec query
		end

		def pull_and_process_orders( args = {} )
			order_ids = []

			args[:params] ||= {}
			args[:params].each do |key, value|
				args[:params][key] = value.strftime('%Y-%m-%dT%H:%M:%S%:z') if value.respond_to? :strftime
			end

			order_batch_where = "WHERE updated_at <= '#{(args[:updated_at_max] || Time.now).strftime('%Y-%m-%dT%H:%M:%S%:z')}'"
			order_batch_where = "#{order_batch_where} AND type = '#{@order_type}'" if @order_type
			order_batch_where = "#{order_batch_where} AND source = '#{@order_source}'" if @order_source
			order_batch_where = "#{order_batch_where} AND updated_at >= '#{args[:updated_at_min].strftime('%Y-%m-%dT%H:%M:%S%:z')}'" if args[:updated_at_min]

			order_ids_query = <<-SQL
				SELECT id, updated_at FROM bazaar_orders #{order_batch_where} ORDER BY id ASC;
			SQL
			puts order_ids_query
			order_ids = exec_query(order_ids_query).collect{|row| row['id'] }

			page = 1
			limit = args[:params][:limit] || 50

			order_id_batches = order_ids.in_groups_of(limit, false).collect{|g| g.join(',')}

			order_batch_query = <<-SQL
				SELECT * FROM bazaar_orders WHERE id IN ({order_ids}) ORDER BY id ASC;
			SQL


			order_id_batches.each_with_index do |order_ids, index|
				page = (index + 1)
				puts "Loading Next Page #{page} / #{order_id_batches.count}"

				page_query = order_batch_query.gsub('{order_ids}', order_ids)
				# puts page_query
				src_orders = exec_query( page_query )

				puts "Processing Page #{page} / #{order_id_batches.count} (count #{src_orders.count})"

				src_orders.each do |src_order|
					src_order.symbolize_keys!

					if src_order[:status].to_i == ORDER_STATUS_ACTIVE || TransactionItem.where( data_src: @data_src, src_transaction_id: src_order[:id] ).present?

						src_order[:properties] = parse_hstore_string( src_order[:properties] )
						src_order[:total] = src_order[:total].to_i

						process_order( src_order, @data_src, 'pull' )
					end
				end
				puts "Completed Page #{page} / #{order_id_batches.count}"

			end

			puts "Finished"
		end

		def pull_and_process_subscriptions_updates( args = {} )
			args[:params] ||= {}
			args[:params].each do |key, value|
				args[:params][key] = value.strftime('%Y-%m-%dT%H:%M:%S%:z') if value.respond_to? :strftime
			end

			page = 1
			limit = args[:params][:limit] || 50



			subscription_batch_where = nil
			subscription_batch_where = "#{subscription_batch_where} AND updated_at >= '#{args[:updated_at_min].strftime('%Y-%m-%dT%H:%M:%S%:z')}'" if args[:updated_at_min]
			subscription_batch_where = "#{subscription_batch_where} AND updated_at <= '#{args[:updated_at_max].strftime('%Y-%m-%dT%H:%M:%S%:z')}'" if args[:updated_at_max]
			subscription_batch_where = subscription_batch_where.gsub(/^\s+AND/,'WHERE') if subscription_batch_where


			subscription_ids_query = <<-SQL
				SELECT id, updated_at FROM bazaar_subscriptions #{subscription_batch_where} ORDER BY id ASC;
			SQL
			puts subscription_ids_query
			subscription_ids = exec_query(subscription_ids_query).collect{|row| row['id'] }

			page = 1
			limit = args[:params][:limit] || 50

			subscription_id_batches = subscription_ids.in_groups_of(limit, false).collect{|g| g.join(',')}

			subscription_batch_query = <<-SQL
				SELECT * FROM bazaar_subscriptions WHERE id IN ({subscription_ids}) ORDER BY id ASC;
			SQL


			subscription_id_batches.each_with_index do |subscription_ids, index|
				page = index + 1
				puts "Loading Next Page #{page} / #{subscription_id_batches.count}"

				page_query = subscription_batch_query.gsub('{subscription_ids}', subscription_ids)
				# puts page_query
				src_subscriptions = exec_query( page_query )

				puts "Processing Page #{page} / #{subscription_id_batches.count} (count #{src_subscriptions.count})"

				src_subscriptions.each do |src_subscription|
					src_subscription.symbolize_keys!
					augement_subscription( src_subscription )

					subscriptions = Subscription.where( data_src: src_subscription[:subscription_data_src].to_s, src_subscription_id: src_subscription[:src_subscription_id].to_s )
					subscriptions.each do |subscription|
						subscription.status					= ( src_subscription[:status].to_i == SUBSCRIPTION_STATUS_ACTIVE ? 'active' : 'canceled' )
						subscription.canceled_at			= src_subscription[:canceled_at]
						subscription.current_period_end		= src_subscription[:current_period_end_at]
						subscription.current_period_start	= src_subscription[:current_period_start_at]
						subscription.ended_at				= src_subscription[:ended_at]
						subscription.effective_ended_at		= src_subscription[:ended_at]
						puts "subscription.changes #{subscription.changes.to_json}" if subscription.changes.present?
						subscription.save
					end
				end

				puts "Completed Page #{page} / #{subscription_id_batches.count}"

			end

			puts "Finished"
		end

		protected

		def augement_subscription( src_subscription )
			src_subscription[:properties] = parse_hstore_string( src_subscription[:properties] )

			if src_subscription[:properties][:recharge_subscription_id].present?
				src_subscription[:src_subscription_id] = src_subscription[:properties][:recharge_subscription_id]
				src_subscription[:subscription_data_src] = ShopifyEtl.DATA_SRC
			else
				src_subscription[:src_subscription_id] = src_subscription[:id]
				src_subscription[:subscription_data_src] = @data_src
			end

		end

		def parse_hstore_string( string )
			JSON.parse "{ #{string.gsub('=>', ':').gsub(':NULL',':null')} }", symbolize_names: true
		end

		def extract_additional_attributes_for_order( src_order )

			src_order[:amount] = src_order[:amount].to_i
			src_order[:status] = src_order[:status].to_i
			src_order[:subtotal] = src_order[:subtotal].to_i
			src_order[:tax] = src_order[:tax].to_i
			src_order[:shipping] = src_order[:shipping].to_i
			src_order[:total] = src_order[:total].to_i
			src_order[:payment_status] = src_order[:payment_status].to_i
			src_order[:fulfillment_status] = src_order[:fulfillment_status].to_i

			src_order[:billing_address] = exec_query("SELECT * FROM geo_addresses WHERE id = #{src_order[:billing_address_id]}").first.symbolize_keys
			src_order[:billing_address][:geo_state] = exec_query("SELECT * FROM geo_states WHERE id = #{src_order[:billing_address][:geo_state_id]}").first.try(:symbolize_keys) if src_order[:billing_address][:geo_state_id].present?
			src_order[:billing_address][:geo_country] = exec_query("SELECT * FROM geo_countries WHERE id = #{src_order[:billing_address][:geo_country_id]}").first.symbolize_keys


			src_order[:shipping_address] = exec_query("SELECT * FROM geo_addresses WHERE id = #{src_order[:shipping_address_id]}").first.symbolize_keys
			src_order[:shipping_address][:geo_state] = exec_query("SELECT * FROM geo_states WHERE id = #{src_order[:shipping_address][:geo_state_id]}").first.try(:symbolize_keys) if src_order[:shipping_address][:geo_state_id].present?
			src_order[:shipping_address][:geo_country] = exec_query("SELECT * FROM geo_countries WHERE id = #{src_order[:shipping_address][:geo_country_id]}").first.symbolize_keys

			src_order[:user] = src_order[:customer] = exec_query("SELECT * FROM users WHERE id = #{src_order[:user_id]}").first.symbolize_keys if src_order[:user_id].present?
			src_order[:wholesale_client] = exec_query("SELECT * FROM wholesale_clients WHERE user_id = #{src_order[:user_id]}").first.try(:symbolize_keys) if src_order[:user_id].present?

			src_order[:shipments] = exec_query("SELECT * FROM bazaar_shipments WHERE order_id = #{src_order[:id]} ORDER BY id ASC").to_a.collect(&:symbolize_keys)
			src_order[:shipments].each do |shipment|
				shipment[:status] = shipment[:status].to_i
			end

			# first shipped?
			if ( shipment = src_order[:shipments].select{|shipment| shipment[:shipped_at].present? }.last ).present?
				src_order[:fulfilled_at] ||= shipment[:shipped_at]
			end

			# all canceled?
			if src_order[:shipments].present? && ( canceled_shipments = src_order[:shipments].select{|shipment| shipment[:canceled_at].present? } ).count == src_order[:shipments].count
				src_order[:fulfillment_canceled_at] ||= canceled_shipments.first[:canceled_at]
			end


			src_order[:transactions] = exec_query("SELECT * FROM bazaar_transactions WHERE parent_obj_id = #{src_order[:id]} AND parent_obj_type = 'Bazaar::Order' ORDER BY id ASC").to_a.collect(&:symbolize_keys)
			src_order[:transactions].each do |transaction|
				transaction[:transaction_type] = transaction[:transaction_type].to_i
				transaction[:amount] = transaction[:amount].to_i
				transaction[:status] = transaction[:status].to_i
			end

			src_order[:order_items] = exec_query("SELECT * FROM bazaar_order_items WHERE order_id = #{src_order[:id]}").to_a.collect(&:symbolize_keys)
			src_order[:order_items].each do |order_item|

				order_item[:quantity] = order_item[:quantity].to_i
				order_item[:price] = order_item[:price].to_i
				order_item[:subtotal] = order_item[:subtotal].to_i

				order_item[:subscription] ||= extract_item( 'Bazaar::Subscription', order_item[:subscription_id] )
				order_item[:item] ||= extract_item( order_item[:item_type], order_item[:item_id] )
				order_item[:subscription] ||= order_item[:item] if order_item[:item_type] == 'Bazaar::Subscription'

			end

			# puts JSON.pretty_generate src_order
			# die()

			src_order
		end

		def extract_additional_attributes_for_refund( src_refund )
			src_refund
		end

		def extract_aggregate_adjustments_from_src_refund( src_refund )

			refund_attributes = {}

			#refund_attributes[:sub_total] = refund_sub_total if refund_sub_total.present?
			# refund_attributes[:tax] = refund_tax if refund_tax.present?
			# refund_attributes[:shipping] = refunded_shipping if refunded_shipping.present?
			# refund_attributes[:shipping_tax] = refunded_shipping_tax if refunded_shipping_tax.present?
			refund_attributes[:total] = src_refund[:amount].to_i

			# puts "refund_attributes"
			# puts JSON.pretty_generate refund_attributes

			refund_attributes
		end

		def extract_channel_partner_from_src_order( src_order )
			refersion_properties = self.get_order_refersion_properties( src_order )
			return nil if refersion_properties[:id].blank?

			channel_partner = ChannelPartner.where( refersion_channel_partner_id: refersion_properties[:affiliate_id] ).first

			channel_partner ||= ChannelPartner.create(
				data_src: @data_src,
				name: refersion_properties[:affiliate_full_name],
				src_channel_partner_id: refersion_properties[:affiliate_id],
				refersion_channel_partner_id: refersion_properties[:affiliate_id],
				# login: referral_data['user_login'],
				# email: referral_data['user_email'],
				# company_name: referral_data['company'],
				# status: status,
			)

			channel_partner.update( name: refersion_properties[:affiliate_full_name] ) unless refersion_properties[:affiliate_full_name].blank?

			if channel_partner.errors.present?
				Rails.logger.info channel_partner.attributes.to_s
				raise Exception.new( channel_partner.errors.full_messages )
			end



			channel_partner
		end

		def extract_coupon_uses_from_src_order( src_order, order )

			coupon_uses = []

			discount_order_items = src_order[:order_items].select{ |order_item| order_item[:order_item_type].to_i == ORDER_ITEM_TYPE_DISCOUNT }


			discount_order_items.each_with_index do |discount_order_item|
				discount_code = discount_order_item[:item]

				coupon = Coupon.where( code: discount_code[:code] ).first_or_create
				coupon.update(
					name: discount_code[:title],
					description: discount_code[:description],
				)
				discount_code[:discount_items].each do |discount_item|
					coupon.update( free_shipping: true ) if [DISCOUNT_ITEM_SHIPPING_ORDER_ITEM_TYPE,DISCOUNT_ITEM_ALL_ORDER_ITEM_TYPES].include? discount_item[:order_item_type]
					coupon.update(
						discount_type: DISCOUNT_TYPE_MAP[discount_item[:discount_type].to_s],
						discount_amount: discount_item[:discount_amount],
					)
				end

				if coupon.errors.present?
					Rails.logger.info coupon.attributes.to_s
					raise Exception.new( coupon.errors.full_messages )
				end

				coupon_use = CouponUse.find_by( data_src: order.data_src, coupon_use_src_id: discount_order_item[:id] )
				coupon_use ||= CouponUse.where(
					data_src: order.data_src,
					src_order_id: order.src_order_id,
					src_transaction_id: order.src_order_id,
					coupon: coupon,
				).first_or_initialize

				coupon_use.attributes = {
					coupon_use_src_id: discount_order_item[:id],
					data_src: order.data_src,
					customer: order.customer,
					location: order.location,
					# subscription: renewed_subscription,
					# offer: offer,
					# product: product,
					channel_partner: order.channel_partner,
					# transaction_type: 'charge',
					campaign: order.campaign,
					source: order.source,
					# amount: (discount_code[:amount] * 100).to_i,
					# tax: coupon_use_data[:tax],
					# shipping: coupon_use_data[:shipping],
					total: discount_order_item[:subtotal].to_i,
					used_at: order.src_created_at,
				}

				puts "coupon_use.changes #{coupon_use.changes.to_json}" if coupon_use.changes.present?
				coupon_use.save!


				if coupon_use.errors.present?
					Rails.logger.info coupon_use.attributes.to_s
					raise Exception.new( coupon_use.errors.full_messages )
				end

				coupon_uses << coupon_use

			end

			coupon_uses
		end

		def extract_customer_from_src_order( src_order, args = {} )
			src_customer = src_order[:customer]

			if src_customer.present?
				customer = Aristotle::Customer.where( email: src_customer[:email] ).first

				customer ||= Aristotle::Customer.create(
					data_src: @data_src,
					src_customer_id: src_customer[:id],
					name: "#{src_customer[:first_name]} #{src_customer[:last_name]}".strip,
					login: src_customer[:email],
					email: src_customer[:email],
				)
			else
				customer = Aristotle::Customer.where( email: src_order[:email] ).first

				customer ||= Aristotle::Customer.create(
					data_src: @data_src,
					src_customer_id: nil,
					name: "#{src_order[:billing_address][:first_name]} #{src_order[:billing_address][:last_name]}".strip,
					login: src_order[:email],
					email: src_order[:email],
				)
			end

			# the src created at for the customer is the smallest created at date
			# for an order
			order_created_at	= Time.parse src_order[:created_at]
			src_created_at		= [ order_created_at, (customer.src_created_at || order_created_at) ].min

			# customer.update( src_customer_id: src_customer[:id], src_created_at: src_created_at )

			if customer.errors.present?
				Rails.logger.info customer.attributes.to_s
				raise Exception.new( customer.errors.full_messages )
			end

			customer

		end

		def extract_id_from_src_order( src_order )
			src_order[:id].to_s
		end

		def extract_id_from_src_refund( src_refund )
			"transaction-#{src_refund[:id]}"
		end

		def extract_item( item_type, item_id )
			return nil unless item_id.present? && item_type.present?

			if item_type == 'Bazaar::Subscription'

				item = exec_query("SELECT * FROM bazaar_subscriptions WHERE id = #{item_id}").first.symbolize_keys

				augement_subscription( item )

				item[:subscription_plan] = extract_item( 'Bazaar::SubscriptionPlan', item[:subscription_plan_id] )

			elsif item_type == 'Bazaar::Product'

				item = exec_query("SELECT * FROM bazaar_products WHERE id = #{item_id}").first.symbolize_keys

			elsif item_type == 'Bazaar::SubscriptionPlan'

				item = exec_query("SELECT * FROM bazaar_subscription_plans WHERE id = #{item_id}").first.symbolize_keys
				item[:item] = extract_item( item[:item_type], item[:item_id] )

			elsif item_type == 'Bazaar::Discount'

				item = exec_query("SELECT * FROM bazaar_discounts WHERE id = #{item_id}").first.symbolize_keys
				item[:discount_items] = exec_query("SELECT * FROM bazaar_discount_items WHERE discount_id = #{item[:id]}").to_a.collect(&:symbolize_keys)

				# item[:item] = extract_item( item[:item_type], item[:item_id] )

			end

			item

		end

		def extract_line_items_from_src_refund( src_refund, order_transaction_items )
			return nil # refunds are always amounts, not itemized
		end

		def extract_location_from_src_order( src_order )
			shipping_address = src_order[:shipping_address]

			location = Location.where( zip: shipping_address[:zip] ).first

			location ||= Location.create(
				data_src: @data_src,
				city: shipping_address[:city],
				state_code: shipping_address[:state] || shipping_address[:geo_state].try(:[],:abbrev),
				zip: shipping_address[:zip],
				country_code: shipping_address[:geo_country][:abbrev],
			)


			if location.errors.present?
				Rails.logger.info location.attributes.to_s
				raise Exception.new( location.errors.full_messages )
			end

			location
		end

		def extract_order_from_src_refund( src_refund )
			order = Order.where( data_src: @data_src, src_order_id: src_refund[:parent_obj_id] ).first
			order
		end

		def extract_order_label_from_order( src_order )
			src_order[:code].to_s
		end

		def extract_src_refunds_from_src_order( src_order )
			src_transactions = ( src_order[:transactions] || [] )
			src_transactions = src_transactions.select{ |src_transaction| src_transaction[:transaction_type].to_i < 0 }
			src_transactions.each do |src_transaction|
				src_transaction[:amount] = src_transaction[:amount].to_i
			end

			src_transactions
		end

		def extract_state_attributes_from_order( src_order )
			return src_order[:_state_attributes] if src_order[:_state_attributes].present?


			# Extract timestamps ***************
			transactions = src_order[:transactions] || []
			refunds = self.extract_src_refunds_from_src_order( src_order )

			timestamps = {
				src_created_at: src_order[:created_at],
				canceled_at: src_order[:fulfillment_canceled_at],
				pending_at: src_order[:created_at],
				pre_ordered_at: nil,
				on_hold_at: nil,
				completed_at: src_order[:fulfilled_at],
			}

			timestamps[:refunded_at] = refunds.first[:created_at] if refunds.present?

			# if there are fulfillments, the completed at date is the latest one, if
			# the order has been completly fulfilled, otherwise set the completed
			# date to closed_at

			approved_charge_transactions	= transactions.select{|transaction| transaction[:status] == 1 && transaction[:transaction_type] == 1  }
			transacted_at									= approved_charge_transactions.first[:created_at] if approved_charge_transactions.present?
			timestamps[:processing_at] 		= transacted_at
			timestamps[:transacted_at] 		= transacted_at

			# timestamps[:failed_at]	=


			timestamps.each do |key, time_string|
				timestamps[key] = Time.parse( time_string ).utc.strftime('%Y-%m-%d %H:%M:%S') if key.to_s.ends_with?('_at') && time_string.present?
			end



			# Extract current status ***************
			if src_order[:cancelled_at].present?
				status = 'cancelled'
			elsif timestamps[:refunded_at].present?
				status = 'refunded'
			elsif src_order[:payment_status].to_i == 2 && src_order[:fulfilled_at].present? # paid AND fulfilled
				status = 'completed'
			elsif src_order[:payment_status].to_i == 2 # paid
				status = 'processing'
			else
				status = 'pending'
			end



			# Merge results ***********************
			state_attributes = timestamps.merge( status: status )

			src_order[:_state_attributes] = state_attributes
		end

		def extract_state_attributes_from_src_refund( src_refund )

			timestamps = {
				src_created_at: src_refund[:created_at],
				transacted_at: src_refund[:created_at],
				canceled_at: nil,
				failed_at: nil,
				pending_at: src_refund[:created_at],
				pre_ordered_at: nil,
				on_hold_at: nil,
				processing_at: src_refund[:created_at],
				completed_at: src_refund[:created_at],
				refunded_at: nil,
				status: 'completed',
			}

			timestamps.each do |key, time_string|
				timestamps[key] = Time.parse( time_string ).utc.strftime('%Y-%m-%d %H:%M:%S') if key.to_s.ends_with?('_at') && time_string.present?
			end

			timestamps

		end

		def extract_subscription_from_transaction_item( transaction_item, subscription_attributes )

			if subscription_attributes.present?

				src_subscription_id = subscription_attributes[:src_subscription_id]
				subscription_data_src = subscription_attributes[:subscription_data_src]

				used_subscription_ids = TransactionItem.where( data_src: @data_src, src_subscription_id: src_subscription_id, src_transaction_id: transaction_item.src_transaction_id ).where.not( subscription_id: nil ).select('subscription_id')
				subscription = Subscription.where( data_src: subscription_data_src, src_subscription_id: src_subscription_id ).where.not( id: used_subscription_ids ).first

				subscription ||= Subscription.create(
					data_src: subscription_data_src,
					customer: transaction_item.customer,
					location: transaction_item.location,
					transaction_item: transaction_item,
					offer: transaction_item.offer,
					product: transaction_item.product,
					channel_partner: transaction_item.channel_partner,
					wholesale_client: transaction_item.wholesale_client,
					deny_recurring_commissions: (transaction_item.channel_partner.try(:deny_recurring_commissions) || false),

					payment_type: transaction_item.payment_type,

					src_created_at: transaction_item.src_created_at,
					src_subscription_id: src_subscription_id,
					src_order_id: transaction_item.src_order_id,

					campaign: transaction_item.campaign,
					source: transaction_item.source,

					amount: transaction_item.amount,
					misc_discount: transaction_item.misc_discount,
					coupon_discount: transaction_item.coupon_discount,
					total_discount: transaction_item.total_discount,
					sub_total: transaction_item.sub_total,
					shipping: transaction_item.shipping,
					shipping_tax: transaction_item.shipping_tax,
					tax: transaction_item.tax,
					adjustment: transaction_item.adjustment,
					total: transaction_item.total,

					recurrance_count: 0,
					max_recurrance_count: 0,

					status: ( subscription_attributes[:status].to_i == SUBSCRIPTION_STATUS_ACTIVE ? 'active' : 'canceled' ),
					removed: nil,

					cancel_at_period_end: nil,
					canceled_at: subscription_attributes[:canceled_at],
					current_period_end: subscription_attributes[:current_period_end_at],
					current_period_start: subscription_attributes[:current_period_start_at],
					on_hold_at: nil,

					ended_at: subscription_attributes[:ended_at],
					start_at: subscription_attributes[:start_at],
					effective_ended_at: subscription_attributes[:ended_at],
					# trial_end_at: nil,
					# trail_start_at: nil,
				)

				if subscription.errors.present?
					Rails.logger.info subscription.attributes.to_s
					raise Exception.new( subscription.errors.full_messages )
				end

			end

			subscription
		end


		def extract_total_from_src_refund( src_refund )
			src_refund[:amount].to_i
		end

		def extract_transaction_items_attributes_from_src_order( src_order, args = {} )

			state_attributes = self.extract_state_attributes_from_order( src_order )
			refersion_properties = self.get_order_refersion_properties( src_order )
			payment_type = self.get_order_payment_type( src_order )

			transaction_items_attributes = self.transform_order_items_to_transaction_items_attributes( src_order[:order_items], commission_total: ( refersion_properties[:commission_total] || 0 ) )

			transaction_items_attributes.each do |transaction_item_attributes|
				transaction_item_attributes[:transaction_type]	= 'charge'
				transaction_item_attributes[:payment_type]		= payment_type
				# transaction_item_attributes[:src_customer_id]	= src_order[:user_id]
				transaction_item_attributes.merge!( state_attributes )
			end

			# puts JSON.pretty_generate transaction_items_attributes

			transaction_items_attributes

		end

		def extract_wholesale_client_from_src_order( src_order, args = {} )
			src_wholesale_client = src_order[:wholesale_client]

			if src_wholesale_client.present?
				wholesale_client = WholesaleClient.where( data_src: @data_src, src_wholesale_client_id: src_wholesale_client[:id] ).first
				wholesale_client = WholesaleClient.where_email( src_wholesale_client[:email] ).first if src_wholesale_client[:email]

				business_name = src_wholesale_client[:business_name]
				if business_name.blank? && ( src_customer = src_order[:customer] ).present?
					business_name = "#{src_customer[:first_name]} #{src_customer[:last_name]}".strip
				end
				business_name = src_wholesale_client[:email] if business_name.blank?

				wholesale_client ||= WholesaleClient.create(
					data_src: @data_src,
					src_wholesale_client_id: src_wholesale_client[:id],
					name: business_name,
					email: src_wholesale_client[:email],
					src_created_at: src_wholesale_client[:created_at],
				)

				wholesale_client.name = business_name
				wholesale_client.save

				if wholesale_client.errors.present?
					Rails.logger.info wholesale_client.attributes.to_s
					raise Exception.new( wholesale_client.errors.full_messages )
				end
			end


			wholesale_client

		end




		def get_order_payment_type( src_order )
			payment_type = 'credit_card'
			payment_type
		end

		# id
		# affiliate_id
		# created
		# commission_total
		# currency
		# affiliate_full_name
		# affiliate_first_name
		# affiliate_last_name
		# affiliate_email
		# offer_id
		def get_order_refersion_properties( src_order )
			return src_order[:refersion_properties] if src_order[:refersion_properties].present?
			refersion_properties = {}

			src_order[:properties].each do |key,value|
				if key.to_s.start_with? 'refersion_conversion_'
					refersion_properties[key.to_s.gsub(/^refersion_conversion_/,'').to_sym] = value
				end
			end

			refersion_properties[:conversion_total] = (refersion_properties[:conversion_total].to_f * 100.0).to_i if refersion_properties[:conversion_total].present?

			src_order[:refersion_properties] = refersion_properties
		end

		def is_subscription_renewal_order( src_order )
			src_order[:parent_id].present?
		end

		def is_subscription_order( src_order )
			src_order[:order_items].select{ |order_item| order_item[:item_type].include?( 'SubscriptionPlan' ) }.present?
		end

		# TRANSFORM ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


		def transform_line_item_to_offer( prod_order_item )

			offer_type = 'default'
			offer_type = 'subscription' if prod_order_item[:item_type].include?( 'SubscriptionPlan' )

			if prod_order_item[:item_type] == 'Bazaar::Subscription'

				subscription_item = prod_order_item[:item]
				subscription_plan_item = subscription_item[:subscription_plan]
				product_item = subscription_plan_item[:item]

			elsif prod_order_item[:item_type] == 'Bazaar::SubscriptionPlan'

				subscription_plan_item = prod_order_item[:item]
				product_item = subscription_plan_item[:item]

			elsif prod_order_item[:item_type] == 'Bazaar::ProductVariant'

				product_item = prod_order_item[:item][:product]

			else

				product_item = prod_order_item[:item]

			end

			src_product_id = "Bazaar::Product\##{product_item[:id]}" if product_item.present?
			src_product_id ||= "#{prod_order_item[:item_type]}\##{prod_order_item[:item_id]}"

			sku = prod_order_item[:sku]
			if subscription_plan_item.present?
				sku ||= subscription_plan_item[:trial_sku] if subscription_plan_item[:trial_sku].present? && offer_type == 'subscription'
				sku ||= subscription_plan_item[:product_sku]
			end
			sku ||= product_item[:sku] if product_item.present?


			if ['Qualia.sub.b','Qualia.sub','Qualia.single','Qualia Combo'].include? sku

				product = Product.where( sku: 'Qualia.M1' ).first
				offer = Offer.where( product: product, offer_type: Offer.offer_types[offer_type] ).first

			else

				product ||= Product.where( data_src: @data_src, src_product_id: src_product_id ).first
				product ||= Product.create(
					name: prod_order_item[:title],
					data_src: @data_src,
					src_product_id: src_product_id,
					sku: sku,
					description: nil,
					# status: product_status,
				)

				if product.errors.present?
					Rails.logger.info product.attributes.to_s
					raise Exception.new( product.errors.full_messages )
				end

				offer = Offer.where( product: product, offer_type: Offer.offer_types[offer_type] ).first
				offer ||= Offer.create(
					name: "#{product.name}#{( offer_type == 'subscription' ? ' Subscription' : '' )}",
					sku: "#{product.sku}#{( offer_type == 'subscription' ? '.subscription' : '' )}",
					data_src: @data_src,
					product: product,
					offer_type: offer_type,
				)

				if offer.errors.present?
					Rails.logger.info offer.attributes.to_s
					raise Exception.new( offer.errors.full_messages )
				end

			end

			offer
		end

		def transform_order_items_to_transaction_items_attributes( order_items, args = {} )
			transaction_items_attributes = []

			prod_order_items = order_items.select{ |order_item| order_item[:order_item_type].to_i == ORDER_ITEM_TYPE_PROD }
			shipping_order_items = order_items.select{ |order_item| order_item[:order_item_type].to_i == ORDER_ITEM_TYPE_SHIPPING }
			tax_order_items = order_items.select{ |order_item| order_item[:order_item_type].to_i == ORDER_ITEM_TYPE_TAX }
			discount_order_items = order_items.select{ |order_item| order_item[:order_item_type].to_i == ORDER_ITEM_TYPE_DISCOUNT }

			prod_total = prod_order_items.sum{|order_item| order_item[:subtotal].to_i }
			shipping_total = shipping_order_items.sum{|order_item| order_item[:subtotal].to_i }
			tax_total = tax_order_items.sum{|order_item| order_item[:subtotal].to_i }
			discount_total = discount_order_items.sum{|order_item| order_item[:subtotal].to_i }
			commission_total = (args[:commission_total] || 0).to_i


			prod_order_items.each do |order_item|
				quantity 	= order_item[:quantity].to_i
				offer 		= transform_line_item_to_offer( order_item )

				src_subscription = order_item[:subscription] if order_item[:subscription].present?
				src_subscription = order_item[:item] if order_item[:item_type] == 'Bazaar::Subscription'
				if src_subscription.present?
					src_subscription_id = src_subscription[:src_subscription_id]
					subscription_attributes = src_subscription.merge(
						subscription_id: src_subscription_id,
						src_subscription_id: src_subscription_id,
						subscription_data_src: src_subscription[:subscription_data_src],
					)
				end

				distributed_prices = Array.new(quantity) { |i| order_item[:price].to_i }

				(0..quantity-1).each do |i|
					amount 		= distributed_prices[i]

					transaction_item_attributes = {
						src_line_item_id: order_item[:id].to_s,
						offer: offer,
						product: offer.product,
						src_subscription_id: src_subscription_id.to_s,
						subscription_attributes: subscription_attributes,
						amount: amount,
					}

					transaction_items_attributes << transaction_item_attributes
				end
			end


			ratios = transaction_items_attributes.collect{|item| item[:amount] / prod_total } if prod_total != 0
			ratios = transaction_items_attributes.collect{|item| 1.0 } if prod_total == 0

			distributed_shipping_costs = ShopifyEtl.distribute_ratios( shipping_total, ratios )
			distributed_commissions = ShopifyEtl.distribute_ratios( commission_total, ratios )
			distributed_discounts = ShopifyEtl.distribute_ratios( discount_total, ratios )
			distributed_tax = ShopifyEtl.distribute_ratios( tax_total, ratios )

			transaction_items_attributes.each_with_index do |transaction_item_attributes, index|

				amount = transaction_item_attributes[:amount]
				transaction_item_attributes.merge!(
					commission: distributed_commissions[index],
					misc_discount: distributed_discounts[index].abs,
					coupon_discount: 0,
					total_discount: distributed_discounts[index].abs,
					sub_total: amount + distributed_discounts[index],
					shipping: distributed_shipping_costs[index],
					shipping_tax: 0,
					tax: distributed_tax[index],
					adjustment: 0,
					total: amount + distributed_discounts[index] + distributed_shipping_costs[index] + distributed_tax[index],
				)
			end


			transaction_items_attributes
		end

	end
end

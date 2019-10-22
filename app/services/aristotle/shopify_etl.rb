module Aristotle
	class ShopifyEtl < EcomEtl
		SHOPIFY_STORE = "#{ENV['SHOPIFY_NAME']}.myshopify.com"
		SHOPIFY_EPOCH = '2017-06-13T00:00:00-08:00'
		RECHARGE_SOURCE_NAME = '294517'

		def self.DATA_SRC()
			SHOPIFY_STORE
		end

		def self.shopify_store_name
			SHOPIFY_STORE
		end

		def self.shopify_epoch
			SHOPIFY_EPOCH
		end

		def initialize( args = {} )

			@shop_url = args[:shop_url] || "https://#{ENV['SHOPIFY_API_KEY']}:#{ENV['SHOPIFY_PASSWORD']}@#{ENV['SHOPIFY_NAME']}.myshopify.com/admin"

		end

		def append_shopify_customer_tags( shopify_customer_id, append_tags, args = {} )
			append_tags = [append_tags] unless append_tags.is_a? Array

			result = RestClient.get( "#{@shop_url}/customers/#{shopify_customer_id}.json" )
			shopify_customer = JSON.parse( result, :symbolize_names => true )[:customer]

			update_shopify_customer_tags( shopify_customer, args.merge( append_tags: append_tags ) ) if shopify_customer.present?

		end

		def clear_all_shopify_refersion_tags( args = {} )
			use_shopify_api

			args[:params] ||= {}
			args[:params].each do |key, value|
				args[:params][key] = value.strftime('%Y-%m-%dT%H:%M:%S%:z') if value.respond_to? :strftime
			end

			page = 1

			default_params = {
				limit: 50,
				processed_at_min: SHOPIFY_EPOCH,
				created_at_min: SHOPIFY_EPOCH,
				status: 'any',
				financial_status: 'any',
				fulfillment_status: 'any'
			}.merge( args[:params] )

			puts "Loading Next Page #{page}"
			while( ( shopify_orders = ShopifyAPI::Order.find( :all, params: default_params.merge( page: page ) ) ).present? ) do
				puts "Updating Page #{page} (count #{shopify_orders.count})"
				shopify_orders.each do |shopify_order|

					# skip imported orders (from importer source)
					next if shopify_order.source_name == '1753159' #litextension

					shopify_order = JSON.parse( shopify_order.to_json, :symbolize_names => true )


					if shopify_order[:tags].include?( 'rfsn.affiliate.' )
						tags_from = get_order_tags( shopify_order )
						tags_to = tags_from.select{ |tag| not( tag.starts_with?( 'rfsn.affiliate.' ) ) }.join(', ')

						puts "shopify_order #{shopify_order[:id]}: changing tags from \"#{shopify_order[:tags]}\" to\n        \"#{tags_to}\""

						if Rails.env.production?
							RestClient.put( "#{@shop_url}/orders/#{shopify_order[:id]}.json", { order: { id: shopify_order[:id], tags: tags_to } }.to_json, {content_type: :json} )
						end

					else
						puts "shopify_order #{shopify_order[:id]}: not refersion tags tags from \"#{shopify_order[:tags]}\""
					end

				end
				puts "Completed Page #{page}"

				sleep 5

				page = page + 1
				puts "Loading Next Page #{page}"
			end

			puts "Finished"
		end

		def get_shopify_customer_by( args = {} )
			if args[:email].blank? && args[:id].blank?
				raise Exception.new( "BLANK EMAIL and ID!" )
			end

			if args[:id].present?

				result = RestClient.get( "#{@shop_url}/customers/#{args[:id]}.json" )
				shopify_customer = JSON.parse( result, :symbolize_names => true )[:customer]

			else

				result = RestClient.get( "#{@shop_url}/customers/search.json", params: { query: args[:email] } )
				raw_shopify_customers = JSON.parse( result, :symbolize_names => true )[:customers]

				shopify_customers = raw_shopify_customers.select{|shopify_customer| (shopify_customer[:email] || '').downcase == (args[:email] || '').downcase }

				shopify_customer = shopify_customers.first

			end

			shopify_customer

		end

		def update_shopify_customer_tags( shopify_customer, args = {} )

			tags = shopify_customer[:tags].split(',').collect(&:strip)
			tags = args[:tags] if args[:tags].present?
			tags = tags + args[:append_tags] if args[:append_tags].present?
			tags = tags.uniq.join(',') #dedupe

			shopify_customer[:tags] = tags

			if Rails.env.production? || args[:force]
				puts "Updating Shopify Customer,#{shopify_customer[:id]},with,\"#{tags}\""
				RestClient.put( "#{@shop_url}/customers/#{shopify_customer[:id]}.json", { customer: { id: shopify_customer[:id], tags: tags } }.to_json, {content_type: :json} )
			else
				puts "NOT Updating Shopify Customer,#{shopify_customer[:id]},with,\"#{tags}\",(args[:force]: #{args[:force]})"
			end

		end

		def update_shopify_order_affiliation( shopify_order, refersion_properties, args={} )

			if shopify_order[:tags].include?( 'rfsn.affiliate.' ) && args[:allow_updates] != true
				puts "Skipping update, tags present ( args[:allow_updates]: #{args[:allow_updates]} )"
			else
				tags = shopify_order[:tags]
				refersion_properties.each do |key, value|
					tags = "#{tags}," unless tags.blank?
					tags = "#{tags}rfsn.affiliate.#{key}:#{value}"
				end

				shopify_order[:tags] = tags

				if Rails.env.production? || args[:force]
					puts "Updating Shopify Order #{shopify_order[:id]} with #{tags}"
					RestClient.put( "#{@shop_url}/orders/#{shopify_order[:id]}.json", { order: { id: shopify_order[:id], tags: tags } }.to_json, {content_type: :json} )
				else
					puts "NOT Updating Shopify Order #{shopify_order[:id]} with #{tags} (args[:force]: #{args[:force]})"
				end

			end


		end

		def pull_coupon_updates
			# defer polling coupons for now... coupon reporting is not currently
			# being used.

			# use_shopify_api
			#
			# Coupon.all.find_each( batch_size: 50 ) do |coupon|
			#
			#
			# 	shopify_coupon = ShopifyAPI::Discount.find(coupon.src_coupon_id)
			#
			# 	# coupon.update( ... )
			#
			# end

		end

		def pull_and_process_orders( args = {} )
			use_shopify_api

			args[:params] ||= {}
			args[:params].each do |key, value|
				args[:params][key] = value.strftime('%Y-%m-%dT%H:%M:%S%:z') if value.respond_to? :strftime
			end

			page = 1

			default_params = {
				limit: 50,
				processed_at_min: SHOPIFY_EPOCH,
				created_at_min: SHOPIFY_EPOCH,
				status: 'any',
				financial_status: 'any',
				fulfillment_status: 'any'
			}.merge( args[:params] )

			puts "Loading Next Page #{page}"
			while( ( shopify_orders = ShopifyAPI::Order.find( :all, params: default_params.merge( page: page ) ) ).present? ) do
				puts "Processing Page #{page} (count #{shopify_orders.count})"
				shopify_orders.each do |shopify_order|

					# skip imported orders (from importer source)
					next if shopify_order.source_name == '1753159' #litextension

					shopify_order_properties = JSON.parse( shopify_order.to_json, :symbolize_names => true )

					process_order( shopify_order_properties, SHOPIFY_STORE, 'pull' )

				end
				puts "Completed Page #{page}"

				sleep 5

				page = page + 1
				puts "Loading Next Page #{page}"
			end

			puts "Finished"
		end

		def pull_shopify_orders_by_number( order_number )
			page_size = 50

			latest_shopify_orders = ShopifyEtl.new.pull_shopify_orders( params: { limit: page_size, page: 1 } )
			latest_order_num = latest_shopify_orders.first[:number]

			page = 1 + ( ( latest_order_num - order_number.to_i ) / page_size ).floor

			shopify_orders = latest_shopify_orders
			shopify_orders = ShopifyEtl.new.pull_shopify_orders( params: { limit: page_size, page: page } ) if page > 1

			shopify_orders = shopify_orders.select do |a_shopify_order|
				a_order_number = a_shopify_order[:number]

				a_order_number.to_s == order_number.to_s
			end

			shopify_orders

		end

		def pull_shopify_orders( args = {} )
			use_shopify_api

			default_params = {
				limit: 50,
				processed_at_min: SHOPIFY_EPOCH,
				created_at_min: SHOPIFY_EPOCH,
				status: 'any',
				financial_status: 'any',
				fulfillment_status: 'any'
			}.merge( args[:params] || {} )

			default_params[:page] = 1 if default_params[:page].blank?

			shopify_orders = ShopifyAPI::Order.find( :all, params: default_params )

			shopify_orders.collect do |shopify_order|

				# skip imported orders (from importer source)
				next if shopify_order.source_name == '1753159' #litextension

				shopify_order_properties = JSON.parse( shopify_order.to_json, :symbolize_names => true )

			end

		end

		protected

		def extract_additional_attributes_for_order( shopify_order )

			tags = get_order_tags( shopify_order )

			if tags.include?('Subscription')

				recharge_order = RechargeEtl.new.get_recharge_order( shopify_order[:id] )


				shopify_order[:line_items].each do |shopify_line_item|

					recharge_line_item = recharge_order[:line_items].find do |a_recharge_line_item|
						a_recharge_line_item[:shopify_product_id] == shopify_line_item[:product_id].to_s && a_recharge_line_item[:shopify_variant_id] == shopify_line_item[:variant_id].to_s
					end

					raise Exception.new( "Unable to find subscription corresponding with shopify line item Shopify Order\##{shopify_order[:id]} / ReCharge Order\##{recharge_order[:id]}" ) if recharge_line_item.nil?

					shopify_line_item[:properties] << { name: 'subscription_id', value: recharge_line_item[:subscription_id] }

					shopify_line_item[:properties] << { name: 'subscription_first_order', value: true } if tags.include?('Subscription First Order')

				end

			end

			shopify_order

		end

		def extract_additional_attributes_for_refund( shopify_refund )
			shopify_refund
		end

		def extract_aggregate_adjustments_from_src_refund( shopify_refund )

			refunded_shipping = 0
			refunded_shipping_tax = 0
			refund_sub_total = 0
			refund_tax = 0

			shopify_refund[:order_adjustments].each do |order_adjustment|
				if order_adjustment[:kind] == 'shipping_refund'
					refunded_shipping 		= -( order_adjustment[:amount].to_f * 100 ).to_i.abs
					refunded_shipping_tax 	= -( order_adjustment[:tax_amount].to_f * 100 ).to_i.abs
				end
			end


			shopify_refund[:order_adjustments].each do |order_adjustment|
				if order_adjustment[:kind] == 'refund_discrepancy'
					refund_sub_total 	= ( refund_sub_total || 0 ) + ( order_adjustment[:amount].to_f * 100 ).to_i
					refund_tax 			= ( refund_tax || 0 ) + ( order_adjustment[:tax_amount].to_f * 100 ).to_i
				end
			end

			refund_attributes = {}

			refund_attributes[:sub_total] = refund_sub_total if refund_sub_total.present?
			refund_attributes[:tax] = refund_tax if refund_tax.present?
			refund_attributes[:shipping] = refunded_shipping if refunded_shipping.present?
			refund_attributes[:shipping_tax] = refunded_shipping_tax if refunded_shipping_tax.present?
			refund_attributes[:total] = refund_attributes.values.sum

			# puts "refund_attributes"
			# puts JSON.pretty_generate refund_attributes

			refund_attributes
		end

		def extract_channel_partner_from_src_order( shopify_order )

			refersion_properties = get_order_refersion_properties( shopify_order )

			return nil if refersion_properties.blank? && refersion_properties['id'].blank?

			channel_partner = ChannelPartner.where( refersion_channel_partner_id: refersion_properties['id'] ).first

			full_name = "#{refersion_properties['first_name']} #{refersion_properties['last_name']}".strip

			channel_partner ||= ChannelPartner.create(
				data_src: SHOPIFY_STORE,
				name: full_name,
				src_channel_partner_id: refersion_properties['id'],
				refersion_channel_partner_id: refersion_properties['id'],
				# login: referral_data['user_login'],
				# email: referral_data['user_email'],
				# company_name: referral_data['company'],
				# status: status,
			)

			channel_partner.update( name: full_name )

			if channel_partner.errors.present?
				Rails.logger.info channel_partner.attributes.to_s
				raise Exception.new( channel_partner.errors.full_messages )
			end

			channel_partner
		end

		def extract_coupon_uses_from_src_order( shopify_order, order )

			coupon_uses = []

			discount_codes = shopify_order[:discount_codes] || []

			discount_codes.each_with_index do |discount_code|

				coupon = Coupon.where( code: discount_code[:code] ).first_or_create

				if coupon.errors.present?
					Rails.logger.info coupon.attributes.to_s
					raise Exception.new( coupon.errors.full_messages )
				end

				coupon_use = CouponUse.where(
					data_src: SHOPIFY_STORE,
					src_order_id: order.src_order_id,
					src_transaction_id: order.src_order_id,
					coupon: coupon,
				).first_or_initialize

				coupon_use.attributes = {
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
					# total: (discount_code[:amount] * 100).to_i,

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

		def extract_customer_from_src_order( shopify_order, args = {} )
			shopify_customer = shopify_order[:customer]

			customer = Aristotle::Customer.where( email: shopify_customer[:email] ).first

			# location = args[:location] || load_order_location( order_data )

			customer ||= Aristotle::Customer.create(
				data_src: SHOPIFY_STORE,
				src_customer_id: shopify_customer[:id],
				shopify_customer_id: shopify_customer[:id],
				name: "#{shopify_customer[:first_name]} #{shopify_customer[:last_name]}".strip,
				login: shopify_customer[:email],
				email: shopify_customer[:email],
				# status: status,
				# src_created_at: customer_data['user_registered'] || customer_data['created_at'],
			)

			# the src created at for the customer is the smallest created at date
			# for an order
			order_created_at	= Time.parse shopify_order[:created_at]
			src_created_at		= [ order_created_at, (customer.src_created_at || order_created_at) ].min

			customer.update( shopify_customer_id: shopify_customer[:id], src_created_at: src_created_at )

			if customer.errors.present?
				Rails.logger.info customer.attributes.to_s
				raise Exception.new( customer.errors.full_messages )
			end

			customer

		end

		def extract_id_from_src_order( shopify_order )
			shopify_order[:id].to_s
		end

		def extract_id_from_src_refund( shopify_refund )
			shopify_refund[:id].to_s
		end

		def extract_line_items_from_src_refund( shopify_refund, order_transaction_items )
			return nil unless shopify_refund[:refund_line_items].present?

			line_items = []

			shopify_refund[:refund_line_items].each do |refund_line_item|
				order_line_item_id = refund_line_item[:line_item_id].to_s

				transaction_items = order_transaction_items.select{ |item| item.src_line_item_id == order_line_item_id }

				quantity 	= refund_line_item[:quantity] || transaction_items.count

				line_item = {
					quantity: 			quantity,
					src_line_item_id:	order_line_item_id,
				}

				Etl.NUMERIC_ATTRIBUTES.each do |attr_name|
					line_item[attr_name] = 0
				end

				line_item[:amount] 			= -( refund_line_item[:line_item][:price].to_f * 100 ).to_i * quantity
				line_item[:sub_total] 		= -( refund_line_item[:subtotal].to_f * 100 ).to_i
				line_item[:misc_discount]	= line_item[:amount] - line_item[:sub_total]
				line_item[:tax]				= -( refund_line_item[:total_tax].to_f * 100 ).to_i
				line_item[:total] 			= ( line_item[:sub_total] + line_item[:tax] )

				line_items << line_item
			end

			line_items

		end

		def extract_location_from_src_order( shopify_order )
			shipping_address = shopify_order[:shipping_address]

			location = Location.where( zip: shipping_address[:zip] ).first

			location ||= Location.create(
				data_src: SHOPIFY_STORE,
				city: shipping_address[:city],
				state_code: shipping_address[:province_code],
				zip: shipping_address[:zip],
				country_code: shipping_address[:country_code],
			)


			if location.errors.present?
				Rails.logger.info location.attributes.to_s
				raise Exception.new( location.errors.full_messages )
			end

			location
		end

		def extract_order_from_src_refund( shopify_refund )
			order = Order.where( data_src: SHOPIFY_STORE, src_order_id: shopify_refund[:order_id] ).first

			order
		end

		def extract_order_label_from_order( shopify_order )
			shopify_order[:order_number].to_s
		end

		def extract_src_refunds_from_src_order( shopify_order )
			shopify_refunds = ( shopify_order[:refunds] || [] )

			shopify_refunds.each do |shopify_refund|
				shopify_refund[:order_id] = shopify_order[:id]
			end

			shopify_refunds
		end

		def extract_state_attributes_from_order( shopify_order )
			return shopify_order[:_state_attributes] if shopify_order[:_state_attributes].present?


			# Extract timestamps ***************
			transactions = shopify_order[:transactions] || []
			fulfillments = shopify_order[:fulfillments] || []
			refunds = self.extract_src_refunds_from_src_order( shopify_order )

			timestamps = {
				src_created_at: shopify_order[:created_at],
				canceled_at: shopify_order[:cancelled_at],
				pending_at: shopify_order[:created_at],
				pre_ordered_at: nil,
				on_hold_at: nil,
			}

			timestamps[:refunded_at] = refunds.first[:created_at] if refunds.present?

			# if there are fulfillments, the completed at date is the latest one, if
			# the order has been completly fulfilled, otherwise set the completed
			# date to closed_at
			if shopify_order[:fulfillment_status] == 'fulfilled'
				successful_fulfillments = fulfillments.select{|fulfillment| fulfillment[:status] == 'success' }
				fulfillment_created_dates = successful_fulfillments.collect{ |fulfillment| Time.parse( fulfillment[:created_at] ) }

				timestamps[:completed_at] = fulfillment_created_dates.sort.last
				timestamps[:completed_at] = timestamps[:completed_at].utc.strftime('%Y-%m-%d %H:%M:%S') if timestamps[:completed_at].present?
			end
			timestamps[:completed_at] ||= shopify_order[:closed_at]

			timestamps[:processing_at] 	= shopify_order[:processed_at]
			timestamps[:transacted_at] 	= shopify_order[:processed_at]

			if transactions.present?

				transacted_at 	= transactions.select{|transaction| transaction[:status] == 'success' }.first.try(:[], :created_at)
				failed_at		= nil # transactions.select{|transaction| transaction[:status] != 'success' }.first.try(:created_at)

				if transacted_at.present?
					timestamps[:processing_at] 	= transacted_at
					timestamps[:transacted_at] 	= transacted_at
				end

				timestamps[:failed_at] 		= failed_at

			end

			timestamps.each do |key, time_string|
				timestamps[key] = Time.parse( time_string ).utc.strftime('%Y-%m-%d %H:%M:%S') if key.to_s.ends_with?('_at') && time_string.present?
			end



			# Extract current status ***************
			financial_status = (shopify_order[:financial_status] || '').downcase
			fulfillment_status = (shopify_order[:fulfillment_status] || '').downcase

			if shopify_order[:cancelled_at].present?
				status = 'cancelled'
			elsif financial_status.include?('refunded')
				status = 'refunded'
			elsif fulfillment_status == 'fulfilled' && financial_status == 'paid'
				status = 'completed'
			elsif financial_status == 'paid'
				status = 'processing'
			else
				status = 'pending'
			end



			# Merge results ***********************
			state_attributes = timestamps.merge( status: status )

			shopify_order[:_state_attributes] = state_attributes
		end

		def extract_state_attributes_from_src_refund( shopify_refund )

			timestamps = {
				src_created_at: shopify_refund[:created_at],
				transacted_at: shopify_refund[:processed_at],
				canceled_at: nil,
				failed_at: nil,
				pending_at: shopify_refund[:created_at],
				pre_ordered_at: nil,
				on_hold_at: nil,
				processing_at: shopify_refund[:processed_at],
				completed_at: shopify_refund[:processed_at],
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

				used_subscription_ids = TransactionItem.where( data_src: SHOPIFY_STORE, src_subscription_id: src_subscription_id, src_transaction_id: transaction_item.src_transaction_id ).where.not( subscription_id: nil ).select('subscription_id')
				subscription = Subscription.where( recharge_subscription_id: src_subscription_id ).where.not( id: used_subscription_ids ).first

				subscription ||= Subscription.create(
					data_src: SHOPIFY_STORE,
					customer: transaction_item.customer,
					location: transaction_item.location,
					transaction_item: transaction_item,
					offer: transaction_item.offer,
					product: transaction_item.product,
					channel_partner: transaction_item.channel_partner,
					deny_recurring_commissions: (transaction_item.channel_partner.try(:deny_recurring_commissions) || false),

					payment_type: transaction_item.payment_type,

					src_created_at: transaction_item.src_created_at,
					src_subscription_id: src_subscription_id,
					recharge_subscription_id: src_subscription_id,
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

					status: nil,
					removed: nil,

					cancel_at_period_end: nil,
					canceled_at: nil,
					current_period_end: nil,
					current_period_start: nil,
					on_hold_at: nil,

					ended_at: nil,
					start_at: transaction_item.src_created_at,
					effective_ended_at: nil,
					# trial_end_at: nil,
					# trail_start_at: nil,
				)

				subscription.update( recharge_subscription_id: src_subscription_id )

			end

			subscription
		end


		def extract_total_from_src_refund( shopify_refund )
			-shopify_refund[:transactions].sum{ |transaction| (transaction[:amount].to_f * 100).to_i }
		end

		def extract_transaction_items_attributes_from_src_order( shopify_order, args = {} )

			state_attributes = self.extract_state_attributes_from_order( shopify_order )
			refersion_properties = self.get_order_refersion_properties( shopify_order )
			payment_type = self.get_order_payment_type( shopify_order )

			shipping_cost_total = shopify_order[:shipping_lines].sum{|line| line[:price] }
			shipping_tax_total 	= shopify_order[:shipping_lines].sum{|line| line[:tax] }
			commission_total 	= (refersion_properties['commission'] || 0.0).to_f
			discounts_total 	= shopify_order[:total_discounts]

			transaction_items_attributes = self.transform_line_items_to_transaction_items_attributes( shopify_order[:line_items], src_customer_id: shopify_order[:customer][:id], shipping_cost_total: shipping_cost_total, shipping_tax_total: shipping_tax_total, commission_total: commission_total, discounts_total: discounts_total )

			transaction_items_attributes.each do |transaction_item_attributes|
				transaction_item_attributes[:transaction_type] ||= 'charge'
				transaction_item_attributes[:payment_type] ||= payment_type
			end

			transaction_items_attributes

		end










		def get_order_payment_type( shopify_order )
			payment_type = 'no_payment_type'
			if shopify_order[:gateway].to_s.downcase == 'amazon_payments'
				payment_type = 'amazon_payments'
			elsif shopify_order[:gateway].to_s.downcase == 'paypal'
				payment_type = 'paypal'
			elsif shopify_order[:payment_details].present? && shopify_order[:payment_details][:credit_card_company].present?
				payment_type = 'credit_card'
			elsif shopify_order[:source_name] == RECHARGE_SOURCE_NAME
				payment_type = 'credit_card'
			else
				puts "Shopify Order \##{shopify_order[:id]}: Unable to find payment type! shopify_order[:gateway] #{shopify_order[:gateway]}"
			end

			payment_type
		end

		# currency
		# commission
		# first_name
		# last_name
		# id
		def get_order_refersion_properties( shopify_order )
			return shopify_order[:_refersion_properties] if shopify_order[:_refersion_properties].present?

			tags = get_order_tags( shopify_order )

			refersion_tags = tags.select{|tag| tag.start_with?('rfsn.affiliate.') }

			refersion_properties = Hash[refersion_tags.collect{|tag| tag.gsub(/rfsn\.affiliate\.commission\.|rfsn\.affiliate\./,'').split(':').collect(&:strip)}]

			shopify_order[:_refersion_properties] = refersion_properties
		end

		def get_order_tags( shopify_order )
			return shopify_order[:_tags] if shopify_order[:_tags].present?

			tags = shopify_order[:tags].split(',').collect(&:strip)

			shopify_order[:_tags] = tags
		end

		def is_subscription_renewal_order( shopify_order )

			tags = get_order_tags( shopify_order )

			tags.include?('Subscription Recurring Order')
		end

		def is_subscription_order( shopify_order )

			tags = shopify_order[:tags].split(',').collect(&:strip)

			tags.include?('Subscription First Order')
		end

		# TRANSFORM ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

		def transform_refersion_properties_to_channel_partner( refersion_properties )

		end


		def transform_line_item_to_offer( line_item_data )

			properties = transform_line_item_properties_to_hash( line_item_data )

			offer_type = 'default'
			offer_type = 'subscription' if properties[:subscription_first_order]

			if [11128592847,11128592655,11624988751].include?( line_item_data[:product_id] )
				product = Product.where( sku: 'Qualia.M1' ).first
			end

			product ||= Product.where( src_product_id: line_item_data[:product_id].to_s ).first
			product ||= Product.create(
				data_src: SHOPIFY_STORE,
				name: line_item_data[:title],
				sku: line_item_data[:sku],
				src_product_id: line_item_data[:product_id].to_s,
				description: nil,
				# status: product_status,
			)

			if product.errors.present?
				Rails.logger.info product.attributes.to_s
				raise Exception.new( product.errors.full_messages )
			end

			offer = Offer.where( product: product, offer_type: Offer.offer_types[offer_type] ).first

			offer ||= Offer.create(
				data_src: SHOPIFY_STORE,
				product: product,
				name: "#{product.name}#{( offer_type == 'subscription' ? ' Subscription' : '' )}",
				sku: "#{product.sku}#{( offer_type == 'subscription' ? '.subscription' : '' )}",
				offer_type: offer_type,
			)

			if offer.errors.present?
				Rails.logger.info offer.attributes.to_s
				raise Exception.new( offer.errors.full_messages )
			end

			offer
		end

		def transform_line_item_properties_to_hash( line_item_data )
			hash = {}
			line_item_properties = line_item_data[:properties] || []

			line_item_properties.each do |property|
				hash[property[:name].to_sym] = property[:value]
			end

			hash
		end

		def transform_line_items_to_transaction_items_attributes( line_items, args = {} )
			transaction_items_attributes = []

			shipping_cost_total = ((args[:shipping_cost_total] || 0).to_f * 100).to_i
			shipping_tax_total 	= ((args[:shipping_tax_total] || 0).to_f * 100).to_i
			commission_total 	= ((args[:commission_total] || 0).to_f * 100).to_i
			discounts_total 	= ((args[:discounts_total] || 0).to_f * 100).to_i

			line_items.each do |line_item_data|
				quantity 	= line_item_data[:quantity]
				properties 	= transform_line_item_properties_to_hash( line_item_data )
				offer 		= transform_line_item_to_offer( line_item_data )
				tax_lines	= line_item_data[:tax_lines] || []

				subscription_attributes = nil

				# distributed values
				distributed_discounts = ShopifyEtl.distribute_quantities( (line_item_data[:total_discount].to_f * 100).to_i, quantity )
				distributed_prices = Array.new(quantity) { |i| (line_item_data[:price].to_f * 100).to_i }
				distributed_taxes = ShopifyEtl.distribute_quantities( ( tax_lines.sum{|line| line[:price]}.to_f * 100).to_i, quantity )


				if properties[:subscription_id].present?

					src_subscription_id = properties[:subscription_id].to_s if properties[:subscription_id].present?

					subscription_attributes = {
						subscription_id: src_subscription_id,
						src_subscription_id: src_subscription_id,
						shipping_interval_frequency: properties[:shipping_interval_frequency],
						shipping_interval_unit_type: properties[:shipping_interval_unit_type],
					}
				end



				(0..quantity-1).each do |i|
					amount 		= distributed_prices[i]
					discount 	= distributed_discounts[i]
					tax 		= distributed_taxes[i]


					transaction_item_attributes = {
						src_line_item_id: line_item_data[:id].to_s,

						offer: offer,
						product: offer.product,

						src_subscription_id: properties[:subscription_id].to_s,

						commission: nil,

						amount: amount,
						misc_discount: discount,
						coupon_discount: 0,
						total_discount: discount,
						sub_total: amount - discount,
						shipping: nil,
						shipping_tax: nil,
						tax: tax,
						adjustment: 0,
						total: amount - discount + tax,
					}

					transaction_item_attributes[:subscription_attributes] = subscription_attributes if subscription_attributes.present?

					transaction_items_attributes << transaction_item_attributes
				end
			end

			sub_total = transaction_items_attributes.sum{|item| item[:sub_total]}
			ratios = transaction_items_attributes.collect{|item| item[:sub_total] / sub_total } if sub_total != 0
			ratios = transaction_items_attributes.collect{|item| 1.0 } if sub_total == 0

			distributed_shipping_costs = ShopifyEtl.distribute_ratios( shipping_cost_total, ratios )
			distributed_shipping_taxes = ShopifyEtl.distribute_ratios( shipping_tax_total, ratios )
			distributed_commissions = ShopifyEtl.distribute_ratios( commission_total, ratios )
			distributed_discounts = ShopifyEtl.distribute_ratios( discounts_total, ratios )

			transaction_items_attributes.each_with_index do |transaction_item_attributes, index|
				shipping = transaction_item_attributes[:shipping] = distributed_shipping_costs[index]
				shipping_tax = transaction_item_attributes[:shipping_tax] = distributed_shipping_taxes[index]

				discount_amount = distributed_discounts[index]

				transaction_item_attributes[:misc_discount] = transaction_item_attributes[:misc_discount] + discount_amount
				transaction_item_attributes[:total_discount] = transaction_item_attributes[:total_discount] + discount_amount

				transaction_item_attributes[:sub_total] = transaction_item_attributes[:sub_total] - discount_amount
				transaction_item_attributes[:total] = transaction_item_attributes[:total] + shipping + shipping_tax - discount_amount

				transaction_item_attributes[:commission] = distributed_commissions[index]
			end

			total = transaction_items_attributes.sum{|item| item[:total]}


			if args[:transaction_total].present?

				transaction_total = ((args[:transaction_total] || 0).to_f * 100).to_i

				distributed_adjustments = ShopifyEtl.distribute_ratios( (transaction_total - total), ratios )

				transaction_items_attributes.each_with_index do |transaction_item_attributes, index|

					adjustment = distributed_adjustments[index]

					transaction_item_attributes[:adjustment] = (transaction_item_attributes[:adjustment] || 0) + adjustment

					transaction_item_attributes[:total] = transaction_item_attributes[:total] + adjustment

				end

			end

			transaction_items_attributes
		end

		def use_shopify_api()
			if @shop.nil?
				ShopifyAPI::Base.site = @shop_url
				@shop = ShopifyAPI::Shop.current
			end

			@shop
		end

	end
end

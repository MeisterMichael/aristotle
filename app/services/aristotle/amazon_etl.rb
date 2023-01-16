module Aristotle
	class AmazonEtl < EcomEtl

		MAX_REQUEST_RETRIES = 5
		REQUEST_COOLDOWN_SECONDS = 5.0 # 1.25

		AMAZON_EPOCH = '2017-07-15T00:00:00-08:00'

		UNITED_STATES_MARKETPLACE_ID = 'ATVPDKIKX0DER' # US
		CANADA_MARKETPLACE_ID = 'A2EUQ1WTGCTBG2' # CA
		SPAIN_MARKETPLACE_ID =	'A1RKKUPIHCS9HS' #	ES
		UK_MARKETPLACE_ID =	'A1F83G8C2ARO7P' #	GB
		FRANCE_MARKETPLACE_ID =	'A13V1IB3VIYZZH' #	FR
		GERMANY_MARKETPLACE_ID =	'A1PA6795UKMFR9' #	DE
		ITALY_MARKETPLACE_ID =	'APJ6JRA9NG5V4' #	IT
		BRAZIL_MARKETPLACE_ID =	'A2Q3Y263D00KWC' #	BR
		INDIA_MARKETPLACE_ID =	'A21TJRUUN4KGV' #	IN
		CHINA_MARKETPLACE_ID =	'AAHKV2X7AFYLW' #	CN
		JAPAN_MARKETPLACE_ID =	'A1VC38T7YXB528' #	JP
		AUSTRALIA_MARKETPLACE_ID =	'A39IBJ37TRP1C6' #	AU

		MARKETPLACE_NAMES = {
			UNITED_STATES_MARKETPLACE_ID => 'Amazon.com',
			CANADA_MARKETPLACE_ID => 'Amazon.ca',
			SPAIN_MARKETPLACE_ID => 'Amazon.es',
			UK_MARKETPLACE_ID =>	'Amazon.co.uk',
			FRANCE_MARKETPLACE_ID =>	'Amazon.fr',
			GERMANY_MARKETPLACE_ID =>	'Amazon.de',
			ITALY_MARKETPLACE_ID =>	'Amazon.it',
			BRAZIL_MARKETPLACE_ID =>	'Amazon.br',
			INDIA_MARKETPLACE_ID =>	'Amazon.in',
			CHINA_MARKETPLACE_ID =>	'Amazon.cn',
			JAPAN_MARKETPLACE_ID =>	'Amazon.up',
			AUSTRALIA_MARKETPLACE_ID =>	'Amazon.au',
		}

		MARKETPLACE_COUNTRY_IDS = {
			'US' => UNITED_STATES_MARKETPLACE_ID,
			'CA' => CANADA_MARKETPLACE_ID,
			'ES' => SPAIN_MARKETPLACE_ID,
			'GB' => UK_MARKETPLACE_ID,
			'FR' => FRANCE_MARKETPLACE_ID,
			'DE' => GERMANY_MARKETPLACE_ID,
			'IT' => ITALY_MARKETPLACE_ID,
			'BR' => BRAZIL_MARKETPLACE_ID,
			'IN' => INDIA_MARKETPLACE_ID,
			'CN' => CHINA_MARKETPLACE_ID,
			'JP' => JAPAN_MARKETPLACE_ID,
			'AU' => AUSTRALIA_MARKETPLACE_ID,
		}

		MARKETPLACE_COUNTRY_HOSTS = {
			'US' => 'mws.amazonservices.com',
			'CA' => 'mws.amazonservices.ca',
			'ES' => 'mws-eu.amazonservices.com',
			'GB' => 'mws-eu.amazonservices.com',
			'FR' => 'mws-eu.amazonservices.com',
			'DE' => 'mws-eu.amazonservices.com',
			'IT' => 'mws-eu.amazonservices.com',
			'BR' => 'mws.amazonservices.com',
			'IN' => 'mws.amazonservices.in',
			'CN' => 'mws.amazonservices.com.cn',
			'JP' => 'mws.amazonservices.jp',
			'AU' => 'mws.amazonservices.com.au',
		}

		MARKETPLACE_COUNTRY_HOST_GROUP = {
			'US' => 'US',
			'CA' => 'US',
			'ES' => 'EU',
			'GB' => 'EU',
			'FR' => 'EU',
			'DE' => 'EU',
			'IT' => 'EU',
			'BR' => 'BR',
			'IN' => 'IN',
			'CN' => 'CN',
			'JP' => 'JP',
			'AU' => 'AU',
		}

		MARKETPLACE_CURRENCIES = {
			UNITED_STATES_MARKETPLACE_ID => 'USD',
			CANADA_MARKETPLACE_ID => 'CAD',
			SPAIN_MARKETPLACE_ID => 'EUR',
			UK_MARKETPLACE_ID =>	'GBP',
			FRANCE_MARKETPLACE_ID =>	'EUR',
			GERMANY_MARKETPLACE_ID =>	'EUR',
			ITALY_MARKETPLACE_ID =>	'EUR',
			BRAZIL_MARKETPLACE_ID =>	'BRL',
			INDIA_MARKETPLACE_ID =>	'INR',
			CHINA_MARKETPLACE_ID =>	'CNY',
			JAPAN_MARKETPLACE_ID =>	'JPY',
			AUSTRALIA_MARKETPLACE_ID =>	'AUD',
			'US' => 'USD',
			'CA' => 'CAD',
			'ES' => 'EUR',
			'GB' => 'GBP',
			'FR' => 'EUR',
			'DE' => 'EUR',
			'IT' => 'EUR',
			'BR' => 'BRL',
			'IN' => 'INR',
			'CN' => 'CNY',
			'JP' => 'JPY',
			'AU' => 'AUD',
		}

		SETTLEMENT_AMOUNT_TYPE_MAPPING = {
			"ShippingTax" => "ShippingTax",
	        "Promotion" => "PromotionDiscount",
	        "GiftWrapTax" => "GiftWrapTax",
	        "ShippingPrice" => "ShippingPrice",
	        "GiftWrapPrice" => "GiftWrapPrice",
	        "ItemPrice" => "ItemPrice",
	        "ItemTax" => "ItemTax",
	        "ShippingDiscount" => "ShippingDiscount",
		}


		def self.marketplace_names
			MARKETPLACE_NAMES
		end

		def initialize( args = {} )
			@data_src = 'Amazon'
			@credentials = args[:credentials] || {}

			if args[:marketplace].present?
				@marketplace_country = args[:marketplace]
				@marketplace_id = MARKETPLACE_COUNTRY_IDS[@marketplace_country]
			else
				@marketplace_id = args[:primary_marketplace_id] || ENV['MWS_MARKETPLACE_ID']
				@marketplace_country = MARKETPLACE_COUNTRY_IDS.invert[@marketplace_id]
			end

			@marketplace_host = MARKETPLACE_COUNTRY_HOSTS[@marketplace_country] || 'mws.amazonservices.com'

			marketplace_host_group = MARKETPLACE_COUNTRY_HOST_GROUP[@marketplace_country]

			@credentials[:merchant_id]						||= ENV["MWS_#{marketplace_host_group}_MERCHANT_ID"] || ENV['MWS_MERCHANT_ID']
			@credentials[:aws_access_key_id]			||= ENV["AWS_#{marketplace_host_group}_ACCESS_KEY_ID"] || ENV['AWS_ACCESS_KEY_ID']
			@credentials[:aws_secret_access_key]	||= ENV["AWS_#{marketplace_host_group}_SECRET_ACCESS_KEY"] || ENV['AWS_SECRET_ACCESS_KEY']

			@credentials[:marketplace] = Peddler::Marketplace.new( @marketplace_id, @marketplace_country, @marketplace_host )

			@default_currency = args[:default_currency] || MARKETPLACE_CURRENCIES[@marketplace_id] || 'USD'

			puts "AmazonEtl.new > marketplace_id: #{@marketplace_id}, marketplace_country: #{@marketplace_country}, default_currency: #{@default_currency}, marketplace_host: #{@marketplace_host}, marketplace_host_group: #{marketplace_host_group}"
		end

		def pull_and_process_settlements( args = {} )
			use_report_api

			refunds = []

			response = report_api_get_report_list( report_type_list: ['_GET_V2_SETTLEMENT_REPORT_DATA_FLAT_FILE_V2_'] )

			last_settlement_report_at = nil

			while response.present?

				parsed_response = response.parse

				next_token = parsed_response['NextToken']

				parsed_response['ReportInfo'] = [parsed_response['ReportInfo']] if parsed_response['ReportInfo'].is_a? Hash

				parsed_response['ReportInfo'].each do |report|
					if report.blank?
						puts "Skip settlement #{report} (blank)"
						next
					elsif not( report.is_a?( Hash ) )
						puts "Skip settlement #{report} (not a hash)"
						puts report.class.name
						puts JSON.pretty_generate( report )
						puts JSON.pretty_generate( parsed_response )
						next
					end


					last_settlement_report_at ||= report['AvailableDate'].gsub('T',' ').gsub('+00:00',' UTC')

					report_id = report['ReportId']
					puts "Extracting Refunds from Report #{report_id} #{report['AvailableDate']}"

					report_response = report_api_get_report(report_id)

					report_response_hash = report_response.parse

					new_refunds = self.extract_refunds( report_response_hash )

					puts "  -> Processing #{new_refunds.count} refunds"
					new_refunds.each do |refund|

						self.process_refund( refund, @data_src )

					end

					puts "Extracting Order Updates from Report #{report_id} #{report['AvailableDate']}"
					order_updates = self.extract_order_updates( report_response_hash )

					puts "  -> Processing #{order_updates.count} order updates"
					order_updates.each do |order_update|
						src_transaction_id = order_update.delete(:src_transaction_id)
						# puts "    -> #{src_transaction_id} updating #{order_update.to_json}"

						transaction_items = TransactionItem.where( src_transaction_id: src_transaction_id, data_src: @data_src )
						# puts "    -> found #{transaction_items.count}"
						transaction_items.each do |transaction_item|
							transaction_item.update( order_update )
						end

					end

				end

				response = nil
				response = report_api_get_report_list_by_next_token( next_token ) if next_token.present?

			end

			last_settlement_report_at

		end

		def pull_and_process_orders( args = {} )
			use_order_api

			if args[:created_after].nil? && args[:last_updated_after].nil?
				args[:created_after] = Time.parse( AMAZON_EPOCH )
			end

			page = 1
			limit = 100

			puts "Loading Next Page #{page}"
			response = self.order_api_list_orders( args )

			while response.present?
				next_token = response.parse['NextToken']
				orders = self.extract_orders( response )

				puts "Processing Page #{page} (count #{orders.count}); '#{next_token}'"

				orders.each do |order|
					self.process_order( order, @data_src )
				end

				puts "Completed Page #{page}"

				page = page + 1

				response = nil
				if next_token.present?
					puts "Loading Next Page #{page}"
					response = self.order_api_list_orders_next( next_token )
				end

			end


			puts "Finished"
		end

		def pull_order( order_id )
			use_order_api

			response = self.order_api_get_order( order_id )

			return self.extract_orders( response ).first
		end

		protected

		def convert_amazon_order_currency( amazon_order, created_at )

			currency = amazon_order['OrderTotal']['CurrencyCode']
			created_at = Time.parse( created_at )

			# Save the CurrencyAmount
			amazon_order['OrderTotal']['CurrencyAmount'] = amazon_order['OrderTotal']['Amount']
			amazon_order['OrderItems'].each do |order_item|
				order_item['PromotionDiscount']['CurrencyAmount'] = order_item['PromotionDiscount']['Amount'] if order_item['PromotionDiscount']
				order_item['ItemPrice']['CurrencyAmount'] = order_item['ItemPrice']['Amount'] if order_item['ItemPrice']
				order_item['ItemTax']['CurrencyAmount'] = order_item['ItemTax']['Amount'] if order_item['ItemTax']
				order_item['ItemTotal']['CurrencyAmount'] = order_item['ItemTotal']['Amount'] if order_item['ItemTotal']
			end

			# If Currency is not USD, the convert it, if available
			if currency.downcase != 'usd' && ( currency_rate = CurrencyExchange.find_rate( currency.downcase, 'usd', at: created_at ) ).present?

				amazon_order['ExchangeRate'] = currency_rate.to_f
				amazon_order['OrderTotal']['Amount'] = amazon_order['OrderTotal']['Amount'].to_f * currency_rate.to_f
				amazon_order['OrderItems'].each do |order_item|
					order_item['PromotionDiscount']['Amount'] = order_item['PromotionDiscount']['Amount'].to_f * currency_rate.to_f if order_item['PromotionDiscount']
					order_item['ItemPrice']['Amount'] = order_item['ItemPrice']['Amount'].to_f * currency_rate.to_f if order_item['ItemPrice']
					order_item['ItemTax']['Amount'] = order_item['ItemTax']['Amount'].to_f * currency_rate.to_f if order_item['ItemTax']
					order_item['ItemTotal']['Amount'] = order_item['ItemTotal']['Amount'].to_f * currency_rate.to_f if order_item['ItemTotal']
				end

				# puts JSON.pretty_generate amazon_order

			end

		end

		def extract_additional_attributes_for_order( src_order )
			src_order
		end

		def extract_additional_attributes_for_refund( src_refund )
			src_refund
		end

		def extract_order_label_from_order( src_order )
			self.extract_id_from_src_order( src_order )
		end

		def extract_src_refunds_from_src_order( src_order )
			[]
		end

		def extract_subscription_from_transaction_item( transaction_item, subscription_attributes )
			nil
		end

		def extract_channel_partner_from_src_order( src_order )
			nil
		end

		def extract_coupon_uses_from_src_order( src_order, order )
			[] #@todo
		end

		def extract_customer_from_src_order( amazon_order )

			return nil unless amazon_order['BuyerEmail'].present?

			customer = Aristotle::Customer.where( email: amazon_order['BuyerEmail'] ).first

			customer ||= Aristotle::Customer.create(
				data_src: @data_src,
				src_customer_id: amazon_order['BuyerEmail'],
				name: amazon_order['BuyerName'],
				login: amazon_order['BuyerEmail'],
				email: amazon_order['BuyerEmail'],
				src_created_at: amazon_order['PurchaseDate'],
			)

			customer.first_transacted_at = [ (customer.first_transacted_at || Time.now), Time.parse(amazon_order['PurchaseDate']) ].min if customer.respond_to? :first_transacted_at

			if customer.errors.present?
				Rails.logger.info customer.attributes.to_s
				raise Exception.new( customer.errors.full_messages )
			end

			customer
		end

		def extract_location_from_src_order( amazon_order )

			shipping_address = amazon_order['ShippingAddress']

			return nil unless shipping_address.present?

			location = Location.where( zip: shipping_address['PostalCode'] ).first

			location ||= Location.create(
				data_src: @data_src,
				city: shipping_address['City'],
				state_code: shipping_address['StateOrRegion'],
				zip: shipping_address['PostalCode'],
				country_code: shipping_address['CountryCode'],
			)


			if location.errors.present?
				Rails.logger.info location.attributes.to_s
				raise Exception.new( location.errors.full_messages )
			end

			location

		end

		def extract_billing_location_from_src_order( amazon_order )
			nil
		end

		def extract_shipping_location_from_src_order( amazon_order )
			extract_location_from_src_order( amazon_order )
		end

		def extract_offer_from_order_item( amazon_order_item )

			offer_type = 'default'
			# offer_type = 'renewal'
			# offer_type = 'subscription'

			offer = find_or_create_offer(
				@data_src,
				product_attributes: {
					src_product_id: amazon_order_item['SellerSKU'].to_s,
					sku: amazon_order_item['ASIN'].to_s,
					name: amazon_order_item['Title']
				},
				offer_attributes: {
					src_offer_id: amazon_order_item['SellerSKU'].to_s,
					sku: amazon_order_item['ASIN'].to_s,
					name: amazon_order_item['Title'],
					offer_type: offer_type,
				},
			)
		end


		def extract_order_from_src_refund( amazon_refund )
			order = Order.where( data_src: @data_src, src_order_id: amazon_refund['AmazonOrderId'] ).first

			order
		end

		def extract_orders( order_response )

			orders = []
			orders = order_response.parse['Orders']['Order'] if order_response.parse['Orders']
			orders = [orders] if orders.is_a? Hash

			orders.each do |order|
				puts "order['AmazonOrderId'] #{order['AmazonOrderId']} : #{order['OrderStatus']} : #{order['PurchaseDate']}"
				order_item_response = self.order_api_list_order_items( order['AmazonOrderId'] )

				order_items = order_item_response.parse['OrderItems']['OrderItem']
				order_items = [order_items] if order_items.is_a? Hash

				order['OrderItems'] = order_items

				convert_amazon_order_currency( order, order['PurchaseDate'] ) if order['OrderTotal']

			end

			orders

		end

		def extract_order_updates( settlements )

			order_udpates = {}

			settlements.each do |row|
				if row['order-id'].present? && row['transaction-type'] == 'Order'
					order_udpates[row['order-id']] ||= { src_transaction_id: row['order-id'] }

					if row['amount-description'] == 'Principal'

						order_udpates[row['order-id']][:processing_at]	= row['posted-date-time']
						order_udpates[row['order-id']][:transacted_at]	= row['posted-date-time']
						order_udpates[row['order-id']][:completed_at]	= row['posted-date-time']

					elsif row['amount-description'] == 'Commission'
						order_udpates[row['order-id']][:commission] ||= 0

						order_udpates[row['order-id']][:commission] += (row['amount'].to_f * 100).to_i.abs
					end

				end
			end

			order_udpates.values
		end

		def extract_refunds( settlements )

			refunds = []

			refund_settlements = settlements.select do |row|
				row['order-id'].present? && row['transaction-type'] == 'Refund' && row['amount-description'] == 'Principal'
			end
			refund_settlements = refund_settlements.collect(&:to_hash)

			refund_settlements_grouped = {}

			refund_settlements.each do |refund_settlement|
				order_id = refund_settlement['order-id']
				posted_date = refund_settlement['posted-date-time']
				group_key = "#{order_id}:#{posted_date}"

				refund_settlements_grouped[group_key] ||= []
				refund_settlements_grouped[group_key] << refund_settlement
			end

			refund_settlements_grouped.each do |key,refund_settlements|

				order_items = {}

				refund_total = 0.00
				currency = refund_settlements.first['currency']
				if refund_settlements.first['marketplace-name']
					marketplace_name = refund_settlements.first['marketplace-name']
					puts marketplace_name
					marketpace_id = MARKETPLACE_NAMES.key(marketplace_name)
					currency ||= (MARKETPLACE_CURRENCIES[marketpace_id] || 'USD')
				end

				refund_settlements.each do |refund_settlement|
					order_item_code = refund_settlement['order-item-code']
					amount 			= refund_settlement['amount'].to_f

					refund_total = refund_total + amount

					if order_item_code.present?

						order_item = order_items[order_item_code]
						order_item ||= {
							"OrderItemId" => order_item_code,
							'SellerSKU' => refund_settlement['sku'],
							'ItemTotal' => {
								'Amount' => 0.0,
								'CurrencyCode' => currency,
							},
							# 'QuantityOrdered' => refund_settlement['quantity-purchased'],
						}

						if ( amount_key = SETTLEMENT_AMOUNT_TYPE_MAPPING[refund_settlement['amount-type']] ).present?
							order_item[amount_key] ||= { "CurrencyCode" => currency, "Amount" => 0.00 }
							order_item[amount_key]['Amount'] = order_item[amount_key]['Amount'] + amount
						end

						order_item['ItemTotal']['Amount'] = order_item['ItemTotal']['Amount'] + amount

						if refund_settlement['amount-type'] == 'Promotion'
							order_item['PromotionIds'] ||= []
							order_item['PromotionIds'] << { 'PromotionId' => refund_settlement['promotion-id'] }
						end

						order_items[order_item_code] = order_item

					end


				end

				refund = {
					'AmazonOrderId' => refund_settlements.first['order-id'],
					'RefundDate' => refund_settlements.first['posted-date-time'],
					'OrderTotal' => {
						'Amount' => refund_total,
						'CurrencyCode' => currency,
					},
					'OrderItems' => order_items.values,
					# 'RefundSettlements' => refund_settlements,
				}

				convert_amazon_order_currency( refund, refund['RefundDate'] )


				refunds << refund

			end


			refunds
		end

		def extract_state_attributes_from_order( amazon_order )
			amazon_order_status = amazon_order['OrderStatus']

			# puts JSON.pretty_generate amazon_order

			status = 'pending'

			timestamps = TransactionItem.where( data_src: @data_src, src_transaction_id: amazon_order['AmazonOrderId'] ).limit(1).select(EcomEtl.TIMESTAMP_ATTRIBUTES).first.try(:attributes).try(:symbolize_keys).try(:except,:id)
			timestamps ||= {
				src_created_at: amazon_order['PurchaseDate'],
				pending_at: amazon_order['PurchaseDate'],
				# pre_ordered_at: nil,
				# on_hold_at: nil,
				# failed_at: nil,
			}

			if ['PendingAvailability'].include? amazon_order_status
				status = 'pre_ordered'

			elsif ['Unshipped','PartiallyShipped'].include? amazon_order_status
				timestamps[:processing_at] ||= amazon_order['PurchaseDate']
				timestamps[:transacted_at] ||= amazon_order['PurchaseDate']
				status = 'processing'

			elsif amazon_order_status == 'Shipped'
				timestamps[:processing_at] ||= amazon_order['PurchaseDate']
				timestamps[:transacted_at] ||= amazon_order['PurchaseDate']
				timestamps[:completed_at]  ||= amazon_order['PurchaseDate']
				status = 'completed'

			end

			if amazon_order_status == 'Canceled'

				status = 'cancelled'
				timestamps[:canceled_at] ||= amazon_order['PurchaseDate']

			elsif timestamps[:refunded_at].present?

				status = 'refunded'
			end


			timestamps.each do |key, time_string|
				timestamps[key] = Time.parse( time_string ).utc.strftime('%Y-%m-%d %H:%M:%S') if key.to_s.ends_with?('_at') && time_string.present? && time_string.is_a?(String)
			end

			state_attributes = timestamps.merge( status: status )

			# puts JSON.pretty_generate state_attributes


			state_attributes
		end

		def extract_state_attributes_from_src_refund( amazon_refund )

			timestamps = {
				src_created_at: amazon_refund['RefundDate'],
				transacted_at: amazon_refund['RefundDate'],
				canceled_at: nil,
				failed_at: nil,
				pending_at: amazon_refund['RefundDate'],
				pre_ordered_at: nil,
				on_hold_at: nil,
				processing_at: amazon_refund['RefundDate'],
				completed_at: amazon_refund['RefundDate'],
				refunded_at: nil,
				status: 'completed',
			}

			timestamps.each do |key, time_string|
				timestamps[key] = Time.parse( time_string ).utc.strftime('%Y-%m-%d %H:%M:%S') if key.to_s.ends_with?('_at') && time_string.present?
			end

			timestamps

		end

		def extract_transaction_items_attributes_from_src_order( amazon_order, args = {} )
			transaction_items_attributes = []

			# puts JSON.pretty_generate amazon_order
			currency = @default_currency
			currency = amazon_order['OrderTotal']['CurrencyCode'] if amazon_order['OrderTotal']

			exchange_rate = amazon_order['ExchangeRate']

			amazon_order['OrderItems'].each do |amazon_order_item|
				quantity 	= (amazon_order_item['QuantityOrdered'] || 0).to_i
				quantity	= 1 if quantity == 0 && amazon_order['OrderStatus'] == 'Canceled'

				offer 		= extract_offer_from_order_item( amazon_order_item )

				subscription_attributes = nil

				item_discounts = 0
				item_discounts = (amazon_order_item['PromotionDiscount']['Amount'].to_f * 100).to_i if amazon_order_item['PromotionDiscount'].present?

				amount = 0
				if amazon_order_item['ItemPrice'].present?

					amount = (amazon_order_item['ItemPrice']['Amount'].to_f * 100).to_i / quantity

				elsif ( last_amount = TransactionItem.charge.where( data_src: @data_src, offer: offer ).last.try(:amount) ).present?

					amount = last_amount

				end

				item_taxes = 0
				item_taxes = (amazon_order_item['ItemTax']['Amount'].to_f * 100).to_i if amazon_order_item['ItemTax'].present?

				# distributed values
				distributed_discounts = EcomEtl.distribute_quantities( item_discounts , quantity )
				distributed_taxes = EcomEtl.distribute_quantities( item_taxes, quantity )



				(0..quantity-1).each do |i|
					discount 	= distributed_discounts[i]
					tax 		= distributed_taxes[i]


					transaction_item_attributes = {
						src_line_item_id: amazon_order_item['OrderItemId'],

						offer: offer,
						offer_type: offer.offer_type,
						product: offer.product,

						# src_subscription_id: properties[:subscription_id].to_s,

						amount: amount,
						misc_discount: discount,
						coupon_discount: 0,
						total_discount: discount,
						sub_total: amount - discount,
						shipping: 0,
						shipping_tax: 0,
						tax: tax,
						adjustment: 0,
						total: amount - discount + tax,
						currency: currency,
						exchange_rate: exchange_rate,
					}

					# transaction_item_attributes[:subscription_attributes] = subscription_attributes if subscription_attributes.present?
					if offer.offer_skus.present?

						transaction_item_attributes[:transaction_skus_attributes] = transaction_item_skus_from_offer( offer, time: amazon_order['PurchaseDate'] )

						distribute_transaction_item_values_to_skus( transaction_item_attributes )
					else
						sku = find_or_create_sku(
							@data_src,
							src_sku_id: amazon_order_item['SellerSKU'].to_s,
							code: amazon_order_item['ASIN'].to_s,
							name: amazon_order_item['Title']
						)
						transaction_item_attributes[:transaction_skus_attributes] = [{ sku: sku, sku_value: amount }]
					end

					transaction_items_attributes << transaction_item_attributes
				end
			end

			# sub_total = transaction_items_attributes.sum{|item| item[:sub_total]}.to_f
			# ratios = transaction_items_attributes.collect{|item| item[:sub_total] / sub_total } if sub_total != 0
			# ratios = transaction_items_attributes.collect{|item| 1.0 } if sub_total == 0

			transaction_items_attributes

		end

		def extract_line_items_from_src_refund( amazon_refund, order_transaction_items )
			return nil unless amazon_refund['OrderItems'].present?

			exchange_rate = amazon_refund['ExchangeRate']

			line_items = []

			amazon_refund['OrderItems'].each do |amazon_refund_order_item|

				line_item_id 	= amazon_refund_order_item['OrderItemId']

				transaction_items = order_transaction_items.select{ |item| item.src_line_item_id == line_item_id }

				line_item = {
					quantity: 			transaction_items.count,
					src_subscription_id: transaction_items.first.try(:src_subscription_id),
					src_line_item_id:	line_item_id,
					exchange_rate:	exchange_rate,
				}

				EcomEtl.NUMERIC_ATTRIBUTES.each do |attr_name|
					line_item[attr_name] = 0
				end

				line_item[:coupon_discount] = -( amazon_refund_order_item['PromotionDiscount']['Amount'].to_f * 100 ).to_i.abs if amazon_refund_order_item['PromotionDiscount'].present?
				line_item[:amount] 			= ( amazon_refund_order_item['ItemPrice']['Amount'].to_f * 100 ).to_i if amazon_refund_order_item['ItemPrice'].present?
				line_item[:tax]				= ( amazon_refund_order_item['ItemTax']['Amount'].to_f * 100 ).to_i if amazon_refund_order_item['ItemTax'].present?

				line_item[:total_discount] 	= EcomEtl.sum_key_values( line_item, EcomEtl.AGGREGATE_TOTAL_DISCOUNT_NUMERIC_ATTRIBUTES )
				line_item[:sub_total] 		= EcomEtl.sum_key_values( line_item, EcomEtl.AGGREGATE_SUB_TOTAL_NUMERIC_ATTRIBUTES )
				line_item[:total] 			= EcomEtl.sum_key_values( line_item, EcomEtl.AGGREGATE_TOTAL_NUMERIC_ATTRIBUTES )

				line_items << line_item
			end

			line_items
		end

		def extract_total_from_src_refund( amazon_refund )
			( amazon_refund['OrderTotal']['Amount'].to_f * 100 ).to_i
		end

		def extract_aggregate_adjustments_from_src_refund( amazon_refund )

			refund_attributes = {}

			# refund_attributes[:tax] = -refund_tax if refunded_shipping.present?
			# refund_attributes[:shipping] = refunded_shipping if refunded_shipping.present?
			# refund_attributes[:shipping_tax] = refunded_shipping_tax if refunded_shipping_tax.present?

			refund_attributes
		end

		def extract_id_from_src_order( amazon_order )
			amazon_order['AmazonOrderId'].to_s
		end

		def extract_id_from_src_refund( amazon_refund )
			"refund:#{amazon_refund['RefundDate']}:#{amazon_refund['AmazonOrderId']}"
		end

		def order_api_get_order( order_id )
			order_api_call( :get_order, [order_id] )
		end

		def order_api_list_orders( args = {} )
			order_api_call( :list_orders, [@marketplace_id,args] )
		end

		def order_api_list_orders_next( next_token )
			order_api_call( :list_orders_by_next_token, [next_token] )
		end

		def order_api_list_order_items( amazon_order_id )
			order_api_call( :list_order_items, [amazon_order_id] )
		end

		def order_api_call( method, args )
			api_call( @order_api, method, args )
		end

		def report_api_get_report( report_id )
			report_api_call( :get_report, [report_id] )
		end

		def report_api_get_report_list( args = {} )
			report_api_call( :get_report_list, [args] )
		end

		def report_api_get_report_list_by_next_token( next_token )
			report_api_call( :get_report_list_by_next_token, [next_token] )
		end

		def report_api_call( method, args )
			api_call( @report_api, method, args )
		end

		def api_call( api, method, args )
			timeout_count = 0
			response = nil

			while ( response.nil? )
				begin
					response = api.try( method, *args )

					# cooldown... looks like the api can sustain 8 request every
					# 10 seconds.
					sleep REQUEST_COOLDOWN_SECONDS
					return response
				rescue Peddler::Errors::RequestThrottled => e
					timeout_count = timeout_count + 1
					raise e if timeout_count >= MAX_REQUEST_RETRIES
					puts "AmazonEtl api #{method} Cooling down api"
					sleep 10*timeout_count # need to cool down api
				rescue Excon::Error::ServiceUnavailable => e
					timeout_count = timeout_count + 1
					raise e if timeout_count >= MAX_REQUEST_RETRIES
					puts "AmazonEtl api #{method} Cooling down api"
					sleep 10*timeout_count # need to cool down api
				rescue Excon::Error::Timeout => e
					timeout_count = timeout_count + 1
					raise e if timeout_count >= MAX_REQUEST_RETRIES
					puts "AmazonEtl api #{method} Cooling down api"
					sleep 10*timeout_count # need to cool down api
				end
			end

		end

		def use_report_api
			@report_api ||= MWS.reports( @credentials )
		end

		def use_order_api
			@order_api ||= MWS.orders( @credentials )
		end

	end
end

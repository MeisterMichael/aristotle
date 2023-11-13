# https://github.com/ericcj/amz_sp_api/tree/main/lib/reports-api-model
# https://github.com/ericcj/amz_sp_api/tree/main/lib/orders-api-model

require 'reports-api-model'
require 'orders-api-model'
require 'tokens-api-model'

module Aristotle
	class SpAmazonEtl < EcomEtl

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

		NETHERLANDS_MARKETPLACE_ID =	'A1805IZSGTT6HS' #	NL
		POLAND_MARKETPLACE_ID =	'A1C3SOZRARQ6R3' #	PL
		SWEDEN_MARKETPLACE_ID =	'A2NODRKZP88ZB9' #	SE
		BELGIUM_MARKETPLACE_ID =	'AMEN7PMS3EDWL' #	BE

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
			NETHERLANDS_MARKETPLACE_ID =>	'Amazon.nl',
			POLAND_MARKETPLACE_ID =>	'Amazon.pl',
			SWEDEN_MARKETPLACE_ID =>	'Amazon.se',
			BELGIUM_MARKETPLACE_ID =>	'Amazon.be',
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
			'NL' => NETHERLANDS_MARKETPLACE_ID,
			'PL' => POLAND_MARKETPLACE_ID,
			'SE' => SWEDEN_MARKETPLACE_ID,
			'BE' => BELGIUM_MARKETPLACE_ID,
		}

		MARKETPLACE_COUNTRY_HOSTS = {
			'US' => 'mws.amazonservices.com',
			'CA' => 'mws.amazonservices.ca',
			'BE' => 'mws-eu.amazonservices.com',
			'ES' => 'mws-eu.amazonservices.com',
			'GB' => 'mws-eu.amazonservices.com',
			'FR' => 'mws-eu.amazonservices.com',
			'DE' => 'mws-eu.amazonservices.com',
			'IT' => 'mws-eu.amazonservices.com',
			'NL' => 'mws-eu.amazonservices.com',
			'PL' => 'mws-eu.amazonservices.com',
			'SE' => 'mws-eu.amazonservices.com',
			'BR' => 'mws.amazonservices.com',
			'IN' => 'mws.amazonservices.in',
			'CN' => 'mws.amazonservices.com.cn',
			'JP' => 'mws.amazonservices.jp',
			'AU' => 'mws.amazonservices.com.au',
		}

		DEFAULT_MARKETPLACE_COUNTRY_HOST_GROUP = 'EU'

		MARKETPLACE_COUNTRY_HOST_GROUP = {
			'CA' => 'NA',
			'BR' => 'NA',
			'MX' => 'NA',
			'US' => 'NA',

			'BE' => 'EU',
			'DE' => 'EU',
			'ES' => 'EU',
			'FR' => 'EU',
			'GB' => 'EU',
			'IN' => 'EU',
			'IT' => 'EU',
			'NL' => 'EU',
			'PL' => 'EU',
			'SE' => 'EU',
			
			# 'CN' => 'CN',?
			'AU' => 'FE',
			'JP' => 'FE',
			'SG' => 'FE',
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
			NETHERLANDS_MARKETPLACE_ID =>	'EUR',
			POLAND_MARKETPLACE_ID =>	'EUR',
			SWEDEN_MARKETPLACE_ID =>	'EUR',
			BELGIUM_MARKETPLACE_ID =>	'EUR',
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

			'NL' => 'EUR',
			'PL' => 'EUR',
			'SE' => 'EUR',
			'BE' => 'EUR',
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

			# @marketplace_host = MARKETPLACE_COUNTRY_HOSTS[@marketplace_country] || 'mws.amazonservices.com'
			marketplace_host_group = MARKETPLACE_COUNTRY_HOST_GROUP[@marketplace_country] || DEFAULT_MARKETPLACE_COUNTRY_HOST_GROUP

			@credentials[:refresh_token]			||= ENV["AWS_#{marketplace_host_group}_SP_REFERSH_TOKEN"]
			@credentials[:client_id]				||= ENV["AWS_#{marketplace_host_group}_SP_API_LWA_CLIENT_ID"] || ENV["AWS_SP_API_LWA_CLIENT_ID"]
			@credentials[:client_secret]			||= ENV["AWS_#{marketplace_host_group}_SP_API_LWA_CLIENT_SECRET"] || ENV["AWS_SP_API_LWA_CLIENT_SECRET"]
			@credentials[:aws_access_key_id]		||= ENV["AWS_#{marketplace_host_group}_SP_API_NHC_ANALYTICS_ACCESS_KEY_ID"] || ENV["AWS_SP_API_NHC_ANALYTICS_ACCESS_KEY_ID"]
			@credentials[:aws_secret_access_key]	||= ENV["AWS_#{marketplace_host_group}_SP_API_NHC_ANALYTICS_SECRET_ACCESS_KEY_ID"] || ENV["AWS_SP_API_NHC_ANALYTICS_SECRET_ACCESS_KEY_ID"]

			@credentials[:region]					||= ENV["AWS_#{marketplace_host_group}_SP_REGION"] || marketplace_host_group.downcase #'na' # 'eu'


			# @credentials[:marketplace] = Peddler::Marketplace.new( @marketplace_id, @marketplace_country, @marketplace_host )

			@default_currency = args[:default_currency] || MARKETPLACE_CURRENCIES[@marketplace_id] || 'USD'

			puts "AmazonEtl.new > marketplace_id: #{@marketplace_id}, marketplace_country: #{@marketplace_country}, default_currency: #{@default_currency}, marketplace_host: #{@marketplace_host}"


			AmzSpApi.configure do |config|
				config.refresh_token = @credentials[:refresh_token]
				config.client_id = @credentials[:client_id]
				config.client_secret = @credentials[:client_secret]

				# either use these:
				config.aws_access_key_id = @credentials[:aws_access_key_id]
				config.aws_secret_access_key = @credentials[:aws_secret_access_key]

				# OR config.credentials_provider which is passed along to https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Sigv4/Signer.html, e.g.
				# require 'aws-sdk-core'
				# config.credentials_provider = Aws::STS::Client.new(
				#     region: AmzSpApi::SpConfiguration::AWS_REGION_MAP['eu'],
				#     access_key_id: ENV['AWS_SP_API_NHC_ANALYTICS_ACCESS_KEY_ID'],
				#     secret_access_key: ENV['AWS_SP_API_NHC_ANALYTICS_SECRET_ACCESS_KEY_ID'],
				#   ).assume_role(role_arn: '', role_session_name: SecureRandom.uuid)

				config.region = @credentials[:region]
				config.timeout = 20 # seconds
				# config.debugging = true

				# optional lambdas for caching LWA access token instead of requesting it each time, e.g.:
				config.save_access_token = -> (access_token_key, token) do
					Rails.cache.write("SPAPI-TOKEN-#{access_token_key}", token[:access_token], expires_in: token[:expires_in] - 60)
				end
				config.get_access_token = -> (access_token_key) { Rails.cache.read("SPAPI-TOKEN-#{access_token_key}") }

			end

			@client = AmzSpApi::SpApiClient.new


		end

		def pull_and_process_settlements( args = {} )
			refunds = []
			refund_errors = []
			last_settlement_report_at = nil

			created_since = DateTime.parse((args[:created_after] || 2.weeks.ago).to_s)
			created_until = DateTime.parse(Time.now.to_s)

			begin
				next_token = nil
				api = AmzSpApi::ReportsApiModel::ReportsApi.new(AmzSpApi::SpApiClient.new)


				loop do
					report_options = { 
						# report_types: ['GET_V2_SETTLEMENT_REPORT_DATA_XML'], # Array<String> | A list of report types used to filter reports. When reportTypes is provided, the other filter parameters (processingStatuses, marketplaceIds, createdSince, createdUntil) and pageSize may also be provided. Either reportTypes or nextToken is required.
						# processing_statuses: ['processing_statuses_example'], # Array<String> | A list of processing statuses used to filter reports.
						# marketplace_ids: [@marketplace_id], # Array<String> | A list of marketplace identifiers used to filter reports. The reports returned will match at least one of the marketplaces that you specify.
						# page_size: 10, # Integer | The maximum number of reports to return in a single call.
						# created_since: created_since, # DateTime | The earliest report creation date and time for reports to include in the response, in ISO 8601 date time format. The default is 90 days ago. Reports are retained for a maximum of 90 days.
						# created_until: created_until, # DateTime | The latest report creation date and time for reports to include in the response, in ISO 8601 date time format. The default is now.
						# next_token: 'next_token_example' # String | A string token returned in the response to your previous request. nextToken is returned when the number of results exceeds the specified pageSize value. To get the next page of results, call the getReports operation and include this token as the only parameter. Specifying nextToken with any other parameters will cause the request to fail.
					}
					if next_token.present?
						report_options = {
							next_token: next_token, # String | A string token returned in the response to your previous request. nextToken is returned when the number of results exceeds the specified pageSize value. To get the next page of results, call the getReports operation and include this token as the only parameter. Specifying nextToken with any other parameters will cause the request to fail.
						}
					else
						report_options = { 
							report_types: ['GET_V2_SETTLEMENT_REPORT_DATA_XML'], # Array<String> | A list of report types used to filter reports. When reportTypes is provided, the other filter parameters (processingStatuses, marketplaceIds, createdSince, createdUntil) and pageSize may also be provided. Either reportTypes or nextToken is required.
							marketplace_ids: [@marketplace_id], # Array<String> | A list of marketplace identifiers used to filter reports. The reports returned will match at least one of the marketplaces that you specify.
							page_size: 10, # Integer | The maximum number of reports to return in a single call.
							created_since: created_since, # DateTime | The earliest report creation date and time for reports to include in the response, in ISO 8601 date time format. The default is 90 days ago. Reports are retained for a maximum of 90 days.
							created_until: created_until, # DateTime | The latest report creation date and time for reports to include in the response, in ISO 8601 date time format. The default is now.
						}
					end
					

					# response = reports_api.get_reports(report_options)
					response = report_api_call( :get_reports, [report_options] )

					next_token = response.next_token

					# puts "get_reports"
					# puts JSON.pretty_generate( JSON.parse(response.to_json))
					
					response.reports.each do |report|
						report_id = report[:reportId]
						# puts "settlment report #{report_id}"
						
						# puts JSON.pretty_generate( JSON.parse(report.to_json))
						
						# report_document_reference = reports_api.get_report_document(report[:reportDocumentId])
						report_document_reference = report_api_call( :get_report_document, [report[:reportDocumentId]] )
						
						# puts JSON.pretty_generate( JSON.parse(report_document_reference.to_json))


						report_data_xml = RestClient.get( report_document_reference.url )
						report_data_hash = Hash.from_xml( report_data_xml )
						# puts JSON.pretty_generate(report_data_hash)


						last_settlement_report_at ||= report[:processingEndTime].gsub('T',' ').gsub('+00:00',' UTC')
						# puts "last_settlement_report_at #{last_settlement_report_at}"


						new_refunds = self.extract_refunds( report_data_hash )

						puts "  -> Processing #{new_refunds.count} refunds"
						new_refunds.each do |refund|
							begin
								refund_transaction_items = self.process_refund( refund, @data_src )
								#puts "new_refunds refund['AmazonOrderId'] #{refund['AmazonOrderId']}"
								#puts JSON.pretty_generate(refund)
								#puts JSON.pretty_generate(refund_transaction_items.collect(&:attributes)) if refund_transaction_items.present?
								#die() if refund['AmazonOrderId'] == '114-1101558-0389848'
							rescue Exception => e
								puts "    -> Exception #{e.message} #{refund.to_json}"
								refund_errors << { exception: e, data: refund }
							end
						end

						puts "Extracting Order Updates from Report #{report_id} #{report['AvailableDate']}"
						order_updates = self.extract_order_updates( report_data_hash )

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

					# puts "next_token #{next_token}"
					break unless next_token.present?

				end

			end

			if refund_errors.present?
				raise Exception.new("Refund Errors #{refund_errors.count} #{refund_errors.to_json}")
			end

			last_settlement_report_at

		end

		def pull_and_process_orders( args = {} )

			if args[:created_after].nil? && args[:last_updated_after].nil?
				args[:created_after] = Time.parse( AMAZON_EPOCH )
			end

			page = 1
			limit = 100

			next_token = nil

			marketplace_ids = [@marketplace_id]

			loop do
				begin

					opts = { 
						# created_after: args[:created_after].iso8601(3).to_s, # String | A date used for selecting orders created after (or at) a specified time. Only orders placed after the specified time are returned. Either the CreatedAfter parameter or the LastUpdatedAfter parameter is required. Both cannot be empty. The date must be in ISO 8601 format.
						# created_before: 1.day.ago.iso8601(3).to_s, # String | A date used for selecting orders created before (or at) a specified time. Only orders placed before the specified time are returned. The date must be in ISO 8601 format.
						# last_updated_after: 'last_updated_after_example', # String | A date used for selecting orders that were last updated after (or at) a specified time. An update is defined as any change in order status, including the creation of a new order. Includes updates made by Amazon and by the seller. The date must be in ISO 8601 format.
						# last_updated_before: 'last_updated_before_example', # String | A date used for selecting orders that were last updated before (or at) a specified time. An update is defined as any change in order status, including the creation of a new order. Includes updates made by Amazon and by the seller. The date must be in ISO 8601 format.
						# order_statuses: ['order_statuses_example'], # Array<String> | A list of `OrderStatus` values used to filter the results.  **Possible values:** - `PendingAvailability` (This status is available for pre-orders only. The order has been placed, payment has not been authorized, and the release date of the item is in the future.) - `Pending` (The order has been placed but payment has not been authorized.) - `Unshipped` (Payment has been authorized and the order is ready for shipment, but no items in the order have been shipped.) - `PartiallyShipped` (One or more, but not all, items in the order have been shipped.) - `Shipped` (All items in the order have been shipped.) - `InvoiceUnconfirmed` (All items in the order have been shipped. The seller has not yet given confirmation to Amazon that the invoice has been shipped to the buyer.) - `Canceled` (The order has been canceled.) - `Unfulfillable` (The order cannot be fulfilled. This state applies only to Multi-Channel Fulfillment orders.)
						# fulfillment_channels: ['fulfillment_channels_example'], # Array<String> | A list that indicates how an order was fulfilled. Filters the results by fulfillment channel. Possible values: AFN (Fulfillment by Amazon); MFN (Fulfilled by the seller).
						# payment_methods: ['payment_methods_example'], # Array<String> | A list of payment method values. Used to select orders paid using the specified payment methods. Possible values: COD (Cash on delivery); CVS (Convenience store payment); Other (Any payment method other than COD or CVS).
						# buyer_email: 'buyer_email_example', # String | The email address of a buyer. Used to select orders that contain the specified email address.
						# seller_order_id: 'seller_order_id_example', # String | An order identifier that is specified by the seller. Used to select only the orders that match the order identifier. If SellerOrderId is specified, then FulfillmentChannels, OrderStatuses, PaymentMethod, LastUpdatedAfter, LastUpdatedBefore, and BuyerEmail cannot be specified.
						# max_results_per_page: 56, # Integer | A number that indicates the maximum number of orders that can be returned per page. Value must be 1 - 100. Default 100.
						# easy_ship_shipment_statuses: ['easy_ship_shipment_statuses_example'], # Array<String> | A list of `EasyShipShipmentStatus` values. Used to select Easy Ship orders with statuses that match the specified values. If `EasyShipShipmentStatus` is specified, only Amazon Easy Ship orders are returned.  **Possible values:** - `PendingSchedule` (The package is awaiting the schedule for pick-up.) - `PendingPickUp` (Amazon has not yet picked up the package from the seller.) - `PendingDropOff` (The seller will deliver the package to the carrier.) - `LabelCanceled` (The seller canceled the pickup.) - `PickedUp` (Amazon has picked up the package from the seller.) - `DroppedOff` (The package is delivered to the carrier by the seller.) - `AtOriginFC` (The packaged is at the origin fulfillment center.) - `AtDestinationFC` (The package is at the destination fulfillment center.) - `Delivered` (The package has been delivered.) - `RejectedByBuyer` (The package has been rejected by the buyer.) - `Undeliverable` (The package cannot be delivered.) - `ReturningToSeller` (The package was not delivered and is being returned to the seller.) - `ReturnedToSeller` (The package was not delivered and was returned to the seller.) - `Lost` (The package is lost.) - `OutForDelivery` (The package is out for delivery.) - `Damaged` (The package was damaged by the carrier.)
						# electronic_invoice_statuses: ['electronic_invoice_statuses_example'], # Array<String> | A list of `ElectronicInvoiceStatus` values. Used to select orders with electronic invoice statuses that match the specified values.  **Possible values:** - `NotRequired` (Electronic invoice submission is not required for this order.) - `NotFound` (The electronic invoice was not submitted for this order.) - `Processing` (The electronic invoice is being processed for this order.) - `Errored` (The last submitted electronic invoice was rejected for this order.) - `Accepted` (The last submitted electronic invoice was submitted and accepted.)
						# next_token: 'next_token_example', # String | A string token returned in the response of your previous request.
						# amazon_order_ids: ['amazon_order_ids_example'], # Array<String> | A list of AmazonOrderId values. An AmazonOrderId is an Amazon-defined order identifier, in 3-7-7 format.
						# actual_fulfillment_supply_source_id: 'actual_fulfillment_supply_source_id_example', # String | Denotes the recommended sourceId where the order should be fulfilled from.
						# is_ispu: true, # BOOLEAN | When true, this order is marked to be picked up from a store rather than delivered.
						# store_chain_store_id: 'store_chain_store_id_example' # String | The store chain store identifier. Linked to a specific store in a store chain.
						# "marketplaceIds" => marketplace_ids,
						# marketplace_ids: [@marketplace_id],
					}

					if next_token.present?

						opts[:next_token] = next_token

					else

						opts["marketplaceIds"] = marketplace_ids

						if args[:created_after].present?
							opts[:created_after] = args[:created_after].iso8601(3).to_s 
							opts[:created_before] = 1.day.ago.iso8601(3).to_s
						end

						if args[:last_updated_after].present?
							opts[:last_updated_after] = args[:last_updated_after].iso8601(3).to_s 
							# opts[:last_updated_before] = 1.day.ago.iso8601(3).to_s
						end

					end

					# puts JSON.pretty_generate(opts)
					# result = orders_api.get_orders(marketplace_ids, opts)
					result = order_api_call( :get_orders, [marketplace_ids, opts] )
					# puts result.class.name
					# puts result
					# puts JSON.pretty_generate( JSON.parse(result.to_json))

					next_token = result.payload[:NextToken]
					puts "next_token #{next_token}"

					orders = self.extract_orders( result )

					# puts JSON.pretty_generate(orders)

					orders.each do |order|
						self.process_order( order, @data_src )
					end

					puts "Completed Page #{page}"

					page = page + 1

				rescue AmzSpApi::ApiError => e
					puts "Exception when calling SP-API: #{e}"
				end

				break unless next_token.present?
			end

			puts "Finished"
		end

		def pull_order( order_id )
			# response = orders_api_get_order( order_id )
			response = order_api_call( :get_order, [order_id] )
			# response = orders_api.get_order( order_id )

			return self.extract_orders( response ).first
		end

		protected

		def convert_amazon_order_currency( amazon_order, created_at )

			currency = amazon_order['OrderTotal']['CurrencyCode']
			created_at = Time.parse( created_at.to_s )

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

			buyer_info = amazon_order['BuyerInfo']

			return nil unless buyer_info['BuyerEmail'].present?

			customer = Aristotle::Customer.where( email: buyer_info['BuyerEmail'] ).first

			customer ||= Aristotle::Customer.create(
				data_src: @data_src,
				src_customer_id: buyer_info['BuyerEmail'],
				name: buyer_info['BuyerName'],
				login: buyer_info['BuyerEmail'],
				email: buyer_info['BuyerEmail'],
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
			# puts "extract_order_from_src_refund"
			# puts @data_src
			# puts amazon_refund['AmazonOrderId']
			# puts JSON.pretty_generate(amazon_refund)
			# puts ( order.try(:attributes) ).try(:to_json)
			order
		end

		def extract_orders( order_response )

			orders = order_response.payload[:Orders].collect{|order| JSON.parse(order.to_json) }
			orders = [orders] if orders.is_a? Hash

			orders.each do |order|
				puts "order['AmazonOrderId'] #{order['AmazonOrderId']} : #{order['OrderStatus']} : #{order['PurchaseDate']}"

				amz_order_id = order['AmazonOrderId']


				# puts JSON.pretty_generate( JSON.parse(order.to_json))
				amz_items = order_api_call( :get_order_items, [amz_order_id] ).payload[:OrderItems]
				# amz_items = orders_api.get_order_items(amz_order_id)
				# puts JSON.pretty_generate( JSON.parse(amz_items.to_json))
				# Returns Empty orders_api.get_order_address(amz_order_id)
				# Returns Empty orders_api.get_order_buyer_info(amz_order_id)
				# Redundant... same info as get_orders orders_api.get_order(result_order[:AmazonOrderId]).payload

				order['OrderItems'] = JSON.parse(amz_items.to_json)

				# puts RestClient.get( result.url )

				# order_items = order_item_response.parse['OrderItems']['OrderItem']
				# order_items = [order_items] if order_items.is_a? Hash

				# order['OrderItems'] = order_items

				convert_amazon_order_currency( order, order['PurchaseDate'] ) if order['OrderTotal']

				# puts JSON.pretty_generate(order)
			end

			orders

		end

		def extract_order_updates( settlements )
			# puts settlements.to_json
			# puts "extract_refunds"
			# puts settlements.keys.to_json
			# ["AmazonEnvelope"]
			# puts settlements['AmazonEnvelope'].keys.to_json
			# ["xmlns:java","xmlns:amzn","xmlns:xalan","xmlns:xsi","xsi:noNamespaceSchemaLocation","Header","MessageType","Message"]
			# puts settlements['AmazonEnvelope']['MessageType']
			# SettlementReport
			# puts settlements['AmazonEnvelope']['Message'].keys.to_json
			# ["MessageID","SettlementReport"]
			# puts settlements['AmazonEnvelope']['Message']['SettlementReport'].keys.to_json
			# ["SettlementData","Order","Refund","OtherTransaction","SellerCouponPayment"]

			order_settlements = settlements['AmazonEnvelope']['Message']['SettlementReport']['Order']
			order_settlements = [order_settlements].select(&:present?) unless order_settlements.is_a? Array
			order_settlements ||= []
			# puts "JSON.pretty_generate(order_settlements)"
			# puts JSON.pretty_generate(order_settlements)

			order_udpates = {}

			order_settlements.each do |order_settlement|
				# puts JSON.pretty_generate(order_settlement)

				amazon_order_id = order_settlement['AmazonOrderID']

				order_udpates[amazon_order_id] ||= { src_transaction_id: amazon_order_id }

				fulfillments = order_settlement['Fulfillment']
				fulfillments = [fulfillments].select(&:present?) unless fulfillments.is_a? Array

				fulfillments.each do |fulfillment|
					posted_date = fulfillment['PostedDate']

					order_udpates[amazon_order_id][:processing_at]	= posted_date
					order_udpates[amazon_order_id][:transacted_at]	= posted_date
					order_udpates[amazon_order_id][:completed_at]	= posted_date

					commission = 0.0

					items = fulfillment['Item']
					items = [items].select(&:present?) unless items.is_a? Array
					items.each do |item|
						item_fees = item['ItemFees']
						item_fees = [item_fees].select(&:present?) unless item_fees.is_a? Array

						item_fees.each do |item_fee|
							fees = item_fee['Fee']
							fees = [fees].select(&:present?) unless fees.is_a? Array

							fees.each do |fee|
								if fee['Type'] == 'Commission'
									# puts JSON.pretty_generate(fee)
									commission += -(fee['Amount'].to_f * 100).to_i
									# puts "commission #{amazon_order_id} #{commission}"
								end
							end
						end
					end

					order_udpates[amazon_order_id][:commission] = commission
					# puts order_udpates[amazon_order_id].to_json

				end
			end

			order_udpates.values
		end

		def extract_refunds( settlements )
			# puts settlements.to_json
			# puts "extract_refunds"
			# puts settlements.keys.to_json
			# # ["AmazonEnvelope"]
			# puts settlements['AmazonEnvelope'].keys.to_json
			# # ["xmlns:java","xmlns:amzn","xmlns:xalan","xmlns:xsi","xsi:noNamespaceSchemaLocation","Header","MessageType","Message"]
			# puts settlements['AmazonEnvelope']['MessageType']
			# # SettlementReport
			# puts settlements['AmazonEnvelope']['Message'].keys.to_json
			# # ["MessageID","SettlementReport"]
			# puts settlements['AmazonEnvelope']['Message']['SettlementReport'].keys.to_json
			# # ["SettlementData","Order","Refund","OtherTransaction","SellerCouponPayment"]

			refund_settlements = settlements['AmazonEnvelope']['Message']['SettlementReport']['Refund']
			refund_settlements ||= []
			refund_settlements = [refund_settlements] unless refund_settlements.is_a? Array
			refund_settlements = refund_settlements.select{|refund_settlement| refund_settlement.present? }
			# puts JSON.pretty_generate(refund_settlements)
			# settlements

			refunds = []

			refund_settlements_grouped = {}

			refund_settlements.each do |refund_settlement|
				order_id = refund_settlement['AmazonOrderID']
				posted_date = refund_settlement['Fulfillment']['PostedDate']
				group_key = "#{order_id}:#{posted_date}"

				refund_settlements_grouped[group_key] ||= []
				refund_settlements_grouped[group_key] << refund_settlement
			end

			refund_settlements_grouped.each do |key,refund_settlements|
				# puts "refund_settlements_group #{key} #{refund_settlements.count}"
				order_items = {}
				posted_date = nil
				amazon_order_id = nil

				refund_total = 0.00
				refund_total = 0.00
				refund_shipping = 0.00
				refund_tax = 0.00
				refund_discount = 0.00
				refund_commission = 0.00
				currency = @default_currency #refund_settlements.first['currency']

				if refund_settlements.first['MarketplaceName'].present?
					marketplace_name = refund_settlements.first['MarketplaceName']
					# puts marketplace_name
					marketpace_id = MARKETPLACE_NAMES.key(marketplace_name)
					currency ||= (MARKETPLACE_CURRENCIES[marketpace_id] || 'USD')
				end


				refund_settlements.each do |refund_settlement|
					# puts "JSON.pretty_generate(refund_settlement) #{refund_settlement['AmazonOrderID']}"
					# puts JSON.pretty_generate(refund_settlement)

					amazon_order_id = refund_settlement['AmazonOrderID']
					
					posted_date		= refund_settlement['Fulfillment']['PostedDate']

					adjusted_items = refund_settlement['Fulfillment']['AdjustedItem']
					adjusted_items = [adjusted_items].select(&:present?) unless adjusted_items.is_a? Array
					
					# puts "adjusted_items.count #{adjusted_items.count}"
					adjusted_items.each do |adjusted_item|
						order_item_code	= adjusted_item['AmazonOrderItemCode']
						seller_sku		= adjusted_item['SKU']
						
						# puts "JSON.pretty_generate(adjusted_item)"
						# puts JSON.pretty_generate(adjusted_item)


						adjustments = []
						commission_adjustments = []

						item_price_components = adjusted_item.dig('ItemPriceAdjustments','Component')
						item_price_components = [item_price_components].select(&:present?) unless item_price_components.is_a? Array
						item_price_components.each do |adjustment|
							adjustments << { adjustment_type: "ItemPrice#{adjustment['Type']}", adjustment: adjustment  }
						end

						fee_components = adjusted_item.dig('ItemFeeAdjustments','Fee')
						fee_components = [fee_components].select(&:present?) unless fee_components.is_a? Array
						fee_components.each do |adjustment|
							adjustments << { adjustment_type: "Fee#{adjustment['Type']}", adjustment: adjustment  }
						end

						# puts "JSON.pretty_generate(adjustments)"
						# puts JSON.pretty_generate(adjustments)

						promotion_components = adjusted_item.dig('PromotionAdjustment')
						promotion_components = [promotion_components].select(&:present?) unless promotion_components.is_a? Array
						promotion_components.each do |adjustment|
							adjustments << { adjustment_type: "Promotion#{adjustment['Type']}", adjustment: adjustment  }
						end

						adjustments = adjustments.select{|adjustment_row| adjustment_row[:adjustment].present? }

						total_adjustment_types = [ 'ItemPricePrincipal', 'ItemPriceShipping', 'PromotionShipping', 'ItemPriceTax', 'ShippingTax', 'PromotionTax', 'PromotionPrincipal' ]
						total_adjustments = adjustments.select{ |adjustment_row| total_adjustment_types.include?(adjustment_row[:adjustment_type]) }

						shipping_adjustment_types = [ 'ItemPriceShipping', 'PromotionShipping' ]
						shipping_adjustments = adjustments.select{ |adjustment_row| shipping_adjustment_types.include?(adjustment_row[:adjustment_type]) }

						tax_adjustment_types = [ 'ItemPriceTax', 'ShippingTax', 'PromotionTax' ]
						tax_adjustments = adjustments.select{ |adjustment_row| tax_adjustment_types.include?(adjustment_row[:adjustment_type]) }

						discount_adjustment_types = [ 'PromotionPrincipal' ]
						discount_adjustments = adjustments.select{ |adjustment_row| discount_adjustment_types.include?(adjustment_row[:adjustment_type]) }

						commission_adjustment_types = [ 'FeeCommission' ]
						commission_adjustments = adjustments.select{ |adjustment_row| commission_adjustment_types.include?(adjustment_row[:adjustment_type]) }


						this_refund_total		= total_adjustments.sum{|adjustment_row| adjustment_row[:adjustment]['Amount'].to_f }
						this_refund_shipping	= shipping_adjustments.sum{|adjustment_row| adjustment_row[:adjustment]['Amount'].to_f }
						this_refund_tax			= tax_adjustments.sum{|adjustment_row| adjustment_row[:adjustment]['Amount'].to_f }
						this_refund_discount	= discount_adjustments.sum{|adjustment_row| adjustment_row[:adjustment]['Amount'].to_f }
						this_refund_commission	= commission_adjustments.sum{|adjustment_row| adjustment_row[:adjustment]['Amount'].to_f }
						this_refund_price		= this_refund_total + this_refund_discount - this_refund_tax - this_refund_shipping

						refund_total		= refund_total + this_refund_total
						refund_shipping		= refund_shipping + this_refund_shipping
						refund_tax			= refund_tax + this_refund_tax
						refund_discount		= refund_discount + this_refund_discount
						refund_commission	= refund_commission + this_refund_commission
						 

						# puts "refund_settlement " + [order_item_code, amount, seller_sku, refund_total].to_json

						if order_item_code.present?

							order_item = order_items[order_item_code]
							order_item ||= {
								"OrderItemId" => order_item_code,
								'SellerSKU' => seller_sku,
								'ItemPrice' => {
									'Amount' => this_refund_price,
									'CurrencyCode' => currency,
								},
								'ItemTotal' => {
									'Amount' => this_refund_total,
									'CurrencyCode' => currency,
								},
								'PromotionDiscount' => {
									'Amount' => this_refund_discount,
									'CurrencyCode' => currency,
								},
								'ShippingPrice' => {
									'Amount' => this_refund_shipping,
									'CurrencyCode' => currency,
								},
								'ItemTax' => {
									'Amount' => this_refund_tax,
									'CurrencyCode' => currency,
								},
								'ItemCommission' => {
									'Amount' => this_refund_commission,
									'CurrencyCode' => currency,
								},
								# 'Adjustments' => [],
								# 'RefundSettlments' => [],
								# 'QuantityOrdered' => refund_settlement['quantity-purchased'],
							}

							# order_item['Adjustments'] = order_item['Adjustments'] + adjustments
							# order_item['RefundSettlments'] = (order_item['RefundSettlments'] + [refund_settlement]).uniq


							# if ( amount_key = SETTLEMENT_AMOUNT_TYPE_MAPPING[refund_settlement['amount-type']] ).present?
							# 	order_item[amount_key] ||= { "CurrencyCode" => currency, "Amount" => 0.00 }
							# 	order_item[amount_key]['Amount'] = order_item[amount_key]['Amount'] + amount
							# end

							# if refund_settlement['amount-type'] == 'Promotion'
							# 	order_item['PromotionIds'] ||= []
							# 	order_item['PromotionIds'] << { 'PromotionId' => refund_settlement['promotion-id'] }
							# end

							order_items[order_item_code] = order_item

						end
					end

					

				end

				refund = {
					'AmazonOrderId' => amazon_order_id,
					'RefundDate' => posted_date,
					'OrderTotal' => {
						'Amount' => refund_total,
						'CurrencyCode' => currency,
					},
					'OrderItems' => order_items.values,
					# 'RefundSettlements' => refund_settlements,
				}

				convert_amazon_order_currency( refund, refund['RefundDate'] )

				# puts "refund!!!"
				# puts JSON.pretty_generate( refund )

				refunds << refund

			end

			# puts JSON.pretty_generate(refunds)

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

			state_attributes = timestamps.merge( status: status, data_src_account: @marketplace_country )

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
				data_src_account: @marketplace_country,
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

				item_shipping = 0
				item_shipping = (amazon_order_item['ShippingPrice']['Amount'].to_f * 100).to_i if amazon_order_item['ShippingPrice'].present?


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
				distributed_shipping = EcomEtl.distribute_quantities( item_shipping, quantity )



				(0..quantity-1).each do |i|
					discount 	= distributed_discounts[i]
					tax 		= distributed_taxes[i]
					shipping 	= distributed_shipping[i]


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
						shipping: shipping,
						shipping_tax: 0,
						tax: tax,
						adjustment: 0,
						total: amount - discount + tax + shipping,
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

			# puts "extract_line_items_from_src_refund #{amazon_refund['AmazonOrderId']}"

			amazon_refund['OrderItems'].each do |amazon_refund_order_item|
				# puts "amazon_refund_order_item #{amazon_refund_order_item.to_json}"
				line_item_id 	= amazon_refund_order_item['OrderItemId']

				transaction_items = order_transaction_items.select{ |item| item.src_line_item_id == line_item_id }
				quantity = transaction_items.count

				if quantity == 0 && amazon_refund_order_item['SellerSKU'].present?
					transaction_items = order_transaction_items.select{ |item| item.offer.src_offer_id == amazon_refund_order_item['SellerSKU'].to_s }
					quantity = transaction_items.count
				end

				quantity = amazon_refund_order_item['QuantityOrdered'].to_i if quantity == 0


				line_item = {
					quantity: 			quantity,
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

				if amazon_refund_order_item['ItemPrice'].blank? && amazon_refund_order_item['ItemTotal'].present?
					line_item[:total] 			= ( amazon_refund_order_item['ItemTotal']['Amount'].to_f * 100 ).to_i
					line_item[:amount]			= line_item[:total] + line_item[:total_discount].to_i - line_item[:tax].to_i
					line_item[:sub_total] 		= EcomEtl.sum_key_values( line_item, EcomEtl.AGGREGATE_SUB_TOTAL_NUMERIC_ATTRIBUTES )
				else
					line_item[:total] 			= EcomEtl.sum_key_values( line_item, EcomEtl.AGGREGATE_TOTAL_NUMERIC_ATTRIBUTES )
				end

				# puts "line_item #{line_item.to_json}"

				line_items << line_item
			end

			# puts "line_items #{line_items.to_json}"

			line_items
		end

		def extract_total_from_src_refund( amazon_refund )
			extracted_total = ( amazon_refund['OrderTotal']['Amount'].to_f * 100 ).to_i
			# puts "extracted_total #{extracted_total}"
			# puts amazon_refund.to_json
			extracted_total
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

		def orders_api
			@orders_api ||= AmzSpApi::OrdersApiModel::OrdersV0Api.new(@client)
		end

		def order_api_call( method, args )
			api_call( orders_api, method, args )
		end

		def reports_api
			@reports_api ||= AmzSpApi::ReportsApiModel::ReportsApi.new(AmzSpApi::SpApiClient.new)
		end

		def report_api_call( method, args )
			api_call( reports_api, method, args )
		end

		def api_call( api, method, args )
			puts "api_call #{api.class.name} #{method.to_s} #{args.to_json}"
			timeout_count = 0
			response = nil

			while ( response.nil? )
				begin
					response = api.try( method, *args )

					# cooldown... looks like the api can sustain 8 request every
					# 10 seconds.
					sleep REQUEST_COOLDOWN_SECONDS
					return response
				rescue AmzSpApi::ApiError => e
					timeout_count = timeout_count + 1
					if timeout_count >= MAX_REQUEST_RETRIES
						puts "api_call MAX RETRY EXCEEDED #{timeout_count}: #{api.class.name} #{method.to_s} #{args.to_json}"
						puts e.to_json
						raise e
					else
						puts "api_call RETRY #{timeout_count}: #{api.class.name} #{method.to_s} #{args.to_json}"
						puts e.to_json
					end
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

	end
end

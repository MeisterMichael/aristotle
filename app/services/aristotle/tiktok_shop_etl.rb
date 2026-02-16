require_relative '../../../lib/aristotle/tiktok_shop_client'

module Aristotle
	class TikTokShopEtl < EcomEtl
		include TikTokShopClient

		MAX_PAGE_SIZE = 100

		ORDER_STATUS_MAP = {
			'UNPAID' => 'pending',
			'ON_HOLD' => 'on_hold',
			'AWAITING_SHIPMENT' => 'processing',
			'PARTIALLY_SHIPPING' => 'processing',
			'AWAITING_COLLECTION' => 'processing',
			'IN_TRANSIT' => 'processing',
			'DELIVERED' => 'completed',
			'COMPLETED' => 'completed',
			'CANCELLED' => 'cancelled',
		}.freeze

		def initialize(args = {})
			@data_src = 'TikTok Shop'
			@default_currency = args[:default_currency] || 'USD'
			puts "TikTokShopEtl.new > data_src: #{@data_src}, default_currency: #{@default_currency}"
		end

		def data_src
			@data_src
		end

		# Pull and process orders from TikTok Shop
		def pull_and_process_orders(args = {})
			puts "\n\nTikTokShopEtl#pull_and_process_orders"

			create_time_from = args[:last_updated_after] || args[:created_after] || 90.days.ago
			create_time_to = args[:created_before] || Time.now

			page_token = nil
			page = 1

			loop do
				puts "\n  Page #{page}"

				request_body = {
					page_size: MAX_PAGE_SIZE,
					sort_field: 'CREATE_TIME',
					sort_order: 'ASC',
					create_time_from: create_time_from.to_i,
					create_time_to: create_time_to.to_i,
				}
				request_body[:page_token] = page_token if page_token.present?

				response = tiktok_shop_post('/order/202309/orders/search', request_body)

				orders = response.dig(:data, :orders) || []
				puts "  -> #{orders.count} orders"

				orders.each do |order|
					begin
						src_order = build_src_order(order)
						self.process_order(src_order, @data_src)
					rescue Exception => e
						puts "  -> Error processing order #{order[:order_id]}: #{e.message}"
						NewRelic::Agent.notice_error(e) if defined?(NewRelic)
					end
				end

				page_token = response.dig(:data, :next_page_token)
				break unless page_token.present? && orders.count >= MAX_PAGE_SIZE

				page += 1
			end

			puts "TikTokShopEtl#pull_and_process_orders COMPLETE"
		end

		# Pull and process refunds (reverse orders) from TikTok Shop
		def pull_and_process_refunds(args = {})
			puts "\n\nTikTokShopEtl#pull_and_process_refunds"

			create_time_from = args[:created_after] || args[:last_updated_after] || 90.days.ago
			create_time_to = args[:created_before] || Time.now

			page_token = nil
			page = 1

			loop do
				puts "\n  Refund Page #{page}"

				request_body = {
					page_size: MAX_PAGE_SIZE,
					sort_field: 'CREATE_TIME',
					sort_order: 'ASC',
					create_time_from: create_time_from.to_i,
					create_time_to: create_time_to.to_i,
				}
				request_body[:page_token] = page_token if page_token.present?

				begin
					response = tiktok_shop_post('/return_refund/202309/reverse_orders/search', request_body)
				rescue StandardError => e
					puts "  -> Error fetching refunds: #{e.message}"
					break
				end

				reverse_orders = response.dig(:data, :reverse_orders) || []
				puts "  -> #{reverse_orders.count} reverse orders"

				reverse_orders.each do |reverse_order|
					begin
						src_refund = build_src_refund(reverse_order)
						self.process_refund(src_refund, @data_src)
					rescue Exception => e
						puts "  -> Error processing refund #{reverse_order[:reverse_order_id]}: #{e.message}"
						NewRelic::Agent.notice_error(e) if defined?(NewRelic)
					end
				end

				page_token = response.dig(:data, :next_page_token)
				break unless page_token.present? && reverse_orders.count >= MAX_PAGE_SIZE

				page += 1
			end

			puts "TikTokShopEtl#pull_and_process_refunds COMPLETE"
		end

		protected

		def extract_additional_attributes_for_order(src_order)
			src_order
		end

		def extract_additional_attributes_for_refund(src_refund)
			src_refund
		end

		def extract_src_refunds_from_src_order(src_order)
			[]
		end

		def extract_id_from_src_order(src_order)
			src_order['order_id'].to_s
		end

		def extract_order_label_from_order(src_order)
			src_order['order_id'].to_s
		end

		def extract_state_attributes_from_order(src_order)
			tiktok_status = src_order['tiktok_status'] || 'UNPAID'
			status = ORDER_STATUS_MAP[tiktok_status] || 'pending'

			create_time = src_order['create_time'].present? ? Time.at(src_order['create_time'].to_i) : nil
			paid_time = src_order['paid_time'].present? && src_order['paid_time'].to_i > 0 ? Time.at(src_order['paid_time'].to_i) : nil
			delivery_time = src_order['delivery_time'].present? && src_order['delivery_time'].to_i > 0 ? Time.at(src_order['delivery_time'].to_i) : nil
			cancel_time = src_order['cancel_time'].present? && src_order['cancel_time'].to_i > 0 ? Time.at(src_order['cancel_time'].to_i) : nil

			timestamps = {
				src_created_at: create_time,
				pending_at: create_time,
			}

			if paid_time.present?
				timestamps[:processing_at] = paid_time
				timestamps[:transacted_at] = paid_time
			end

			if delivery_time.present?
				timestamps[:completed_at] = delivery_time
			end

			if cancel_time.present?
				timestamps[:canceled_at] = cancel_time
			end

			timestamps.merge(status: status, data_src_account: 'TikTok Shop')
		end

		def extract_customer_from_src_order(src_order)
			buyer_email = src_order['buyer_email']
			buyer_name = src_order['buyer_name'] || 'TikTok Shop Customer'

			return nil unless buyer_email.present? || buyer_name.present?

			# TikTok Shop may not always provide email, use order_id-based identifier
			customer_id = buyer_email || "tiktok_shop_#{src_order['order_id']}"

			customer = Customer.where(email: buyer_email).first if buyer_email.present?
			customer ||= Customer.where(data_src: @data_src, src_customer_id: customer_id).first

			customer ||= Customer.create(
				data_src: @data_src,
				src_customer_id: customer_id,
				name: buyer_name,
				login: buyer_email,
				email: buyer_email,
				src_created_at: src_order['create_time'].present? ? Time.at(src_order['create_time'].to_i) : nil,
			)

			if customer.respond_to?(:first_transacted_at) && src_order['create_time'].present?
				order_time = Time.at(src_order['create_time'].to_i)
				customer.first_transacted_at = [customer.first_transacted_at || Time.now, order_time].min
			end

			customer
		end

		def extract_location_from_src_order(src_order)
			address = src_order['recipient_address']
			return nil unless address.present?

			zip = address['zipcode'] || address['postal_code']
			return nil unless zip.present?

			location = Location.where(zip: zip).first
			location ||= Location.create(
				data_src: @data_src,
				city: address['city'],
				state_code: address['state'],
				zip: zip,
				country_code: address['region_code'],
			)

			location
		end

		def extract_billing_location_from_src_order(src_order)
			nil
		end

		def extract_shipping_location_from_src_order(src_order)
			extract_location_from_src_order(src_order)
		end

		def extract_channel_partner_from_src_order(src_order)
			nil
		end

		def extract_coupon_uses_from_src_order(src_order, order)
			[]
		end

		def extract_subscription_from_transaction_item(transaction_item, subscription_attributes)
			nil
		end

		def extract_transaction_items_attributes_from_src_order(src_order, args = {})
			transaction_items_attributes = []

			currency = src_order['currency'] || @default_currency
			exchange_rate = nil

			# Convert currency if not USD
			if currency.downcase != 'usd'
				created_at = src_order['create_time'].present? ? Time.at(src_order['create_time'].to_i) : Time.now
				exchange_rate = CurrencyExchange.find_rate(currency.downcase, 'usd', at: created_at)
			end

			items = src_order['line_items'] || []

			items.each do |item|
				offer = extract_offer_from_order_item(item)
				quantity = (item['quantity'] || 1).to_i

				# TikTok amounts are in currency units (not cents), convert to cents
				sale_price = to_cents(item['sale_price'], exchange_rate)
				seller_discount = to_cents(item['seller_discount'], exchange_rate)
				platform_discount = to_cents(item['platform_discount'], exchange_rate)

				# Distribute across quantity
				distributed_prices = EcomEtl.distribute_quantities(sale_price, quantity)
				distributed_seller_discounts = EcomEtl.distribute_quantities(seller_discount, quantity)
				distributed_platform_discounts = EcomEtl.distribute_quantities(platform_discount, quantity)

				(0..quantity - 1).each do |i|
					amount = distributed_prices[i]
					misc_discount = distributed_seller_discounts[i]
					coupon_discount = distributed_platform_discounts[i]
					total_discount = misc_discount + coupon_discount
					sub_total = amount - total_discount
					tax = 0
					shipping = 0
					total = sub_total + tax + shipping

					transaction_item_attributes = {
						src_line_item_id: item['line_item_id'] || item['sku_id'],
						offer: offer,
						offer_type: offer.offer_type,
						product: offer.product,
						amount: amount,
						misc_discount: misc_discount,
						coupon_discount: coupon_discount,
						total_discount: total_discount,
						sub_total: sub_total,
						shipping: shipping,
						shipping_tax: 0,
						tax: tax,
						adjustment: 0,
						total: total,
						currency: currency,
						exchange_rate: exchange_rate,
					}

					# Create SKU attributes
					sku = find_or_create_sku(
						@data_src,
						src_sku_id: (item['sku_id'] || item['product_id']).to_s,
						code: (item['sku_id'] || item['product_id']).to_s,
						name: item['product_name'] || item['sku_name'],
					)
					transaction_item_attributes[:transaction_skus_attributes] = [{ sku: sku, sku_value: amount }]

					transaction_items_attributes << transaction_item_attributes
				end
			end

			transaction_items_attributes
		end

		def extract_offer_from_order_item(item)
			offer_type = 'default'

			find_or_create_offer(
				@data_src,
				product_attributes: {
					src_product_id: (item['product_id'] || item['sku_id']).to_s,
					name: item['product_name'] || item['sku_name'],
				},
				offer_attributes: {
					src_offer_id: (item['sku_id'] || item['product_id']).to_s,
					name: item['sku_name'] || item['product_name'],
					offer_type: offer_type,
				},
			)
		end

		# Refund methods

		def extract_id_from_src_refund(src_refund)
			"refund:#{src_refund['reverse_order_id']}"
		end

		def extract_order_from_src_refund(src_refund)
			Order.where(data_src: @data_src, src_order_id: src_refund['order_id'].to_s).first
		end

		def extract_state_attributes_from_src_refund(src_refund)
			create_time = src_refund['create_time'].present? ? Time.at(src_refund['create_time'].to_i) : Time.now

			{
				src_created_at: create_time,
				transacted_at: create_time,
				pending_at: create_time,
				processing_at: create_time,
				completed_at: create_time,
				canceled_at: nil,
				failed_at: nil,
				pre_ordered_at: nil,
				on_hold_at: nil,
				refunded_at: nil,
				status: 'completed',
				data_src_account: 'TikTok Shop',
			}
		end

		def extract_line_items_from_src_refund(src_refund, order_transaction_items)
			refund_items = src_refund['refund_line_items'] || []
			return nil if refund_items.blank?

			line_items = []

			refund_items.each do |refund_item|
				line_item_id = refund_item['line_item_id'] || refund_item['sku_id']
				quantity = (refund_item['quantity'] || 1).to_i

				transaction_items = order_transaction_items.select { |item| item.src_line_item_id == line_item_id.to_s }
				quantity = transaction_items.count if transaction_items.count > 0 && transaction_items.count < quantity

				refund_amount = to_cents(refund_item['refund_amount'])

				line_item = {
					quantity: quantity,
					src_line_item_id: line_item_id.to_s,
				}

				EcomEtl.NUMERIC_ATTRIBUTES.each do |attr_name|
					line_item[attr_name] = 0
				end

				line_item[:amount] = -refund_amount.abs
				line_item[:total] = -refund_amount.abs
				line_item[:sub_total] = -refund_amount.abs

				line_items << line_item
			end

			line_items.present? ? line_items : nil
		end

		def extract_total_from_src_refund(src_refund)
			refund_total = to_cents(src_refund['refund_total'])
			-refund_total.abs
		end

		def extract_aggregate_adjustments_from_src_refund(src_refund)
			{}
		end

		private

		def build_src_order(tiktok_order)
			payment_info = tiktok_order[:payment_info] || {}
			recipient_address = tiktok_order[:recipient_address] || {}

			line_items = (tiktok_order[:line_items] || []).map do |item|
				{
					'line_item_id' => item[:id].to_s,
					'product_id' => item[:product_id].to_s,
					'product_name' => item[:product_name],
					'sku_id' => item[:sku_id].to_s,
					'sku_name' => item[:sku_name],
					'quantity' => item[:quantity],
					'sale_price' => item[:sale_price],
					'seller_discount' => item[:seller_discount],
					'platform_discount' => item[:platform_discount],
				}
			end

			{
				'order_id' => tiktok_order[:order_id].to_s,
				'tiktok_status' => tiktok_order[:status],
				'create_time' => tiktok_order[:create_time],
				'paid_time' => tiktok_order[:paid_time] || payment_info[:paid_time],
				'delivery_time' => tiktok_order[:delivery_time],
				'cancel_time' => tiktok_order[:cancel_time],
				'buyer_email' => tiktok_order.dig(:buyer_email),
				'buyer_name' => tiktok_order.dig(:buyer_message),
				'currency' => payment_info[:currency] || 'USD',
				'recipient_address' => {
					'full_address' => recipient_address[:full_address],
					'city' => recipient_address[:city],
					'state' => recipient_address[:state],
					'zipcode' => recipient_address[:zipcode] || recipient_address[:postal_code],
					'region_code' => recipient_address[:region_code],
				},
				'line_items' => line_items,
			}
		end

		def build_src_refund(reverse_order)
			refund_line_items = (reverse_order[:reverse_order_line_items] || reverse_order[:items] || []).map do |item|
				{
					'line_item_id' => (item[:id] || item[:order_line_item_id]).to_s,
					'sku_id' => item[:sku_id].to_s,
					'quantity' => item[:quantity] || 1,
					'refund_amount' => item[:refund_amount] || item[:refund_total],
				}
			end

			{
				'reverse_order_id' => reverse_order[:reverse_order_id].to_s,
				'order_id' => reverse_order[:order_id].to_s,
				'create_time' => reverse_order[:create_time],
				'refund_total' => reverse_order[:refund_total] || reverse_order[:refund_amount],
				'refund_line_items' => refund_line_items,
			}
		end

		# Convert a currency amount string to cents (integer)
		def to_cents(amount, exchange_rate = nil)
			return 0 unless amount.present?
			cents = (amount.to_f * 100).round
			cents = (cents * exchange_rate.to_f).round if exchange_rate.present?
			cents
		end

	end
end

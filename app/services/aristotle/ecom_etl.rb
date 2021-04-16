module Aristotle
	class EcomEtl

		# CONSTANTS
		# **************************************************************************

		def self.STATE_ATTRIBUTES
			[ :status, :src_created_at, :transacted_at, :canceled_at, :failed_at, :pending_at, :pre_ordered_at, :on_hold_at, :processing_at, :completed_at, :refunded_at ]
		end

		def self.AGGREGATE_NUMERIC_ATTRIBUTES
			[:total_discount, :sub_total, :total]
		end

		def self.AGGREGATE_TOTAL_NUMERIC_ATTRIBUTES
			[:amount, :misc_discount, :coupon_discount, :shipping, :shipping_tax, :tax, :adjustment]
		end

		def self.AGGREGATE_SUB_TOTAL_NUMERIC_ATTRIBUTES
			[:amount, :total_discount]
		end

		def self.AGGREGATE_TOTAL_DISCOUNT_NUMERIC_ATTRIBUTES
			[:misc_discount, :coupon_discount]
		end

		def self.NUMERIC_ATTRIBUTES
			[ :commission, :amount, :misc_discount, :coupon_discount, :total_discount, :sub_total, :shipping, :shipping_tax, :tax, :adjustment, :total ]
		end

		def self.POSITIVE_NUMERIC_ATTRIBUTES
			[ :commission, :amount, :misc_discount, :coupon_discount, :total_discount, :sub_total, :shipping, :shipping_tax, :tax, :total ]
		end

		def self.NEGATIVE_NUMERIC_ATTRIBUTES
			[ :misc_discount, :coupon_discount, :total_discount ]
		end

		def self.TIMESTAMP_ATTRIBUTES
			[:src_created_at, :transacted_at, :canceled_at, :failed_at, :pending_at, :pre_ordered_at, :on_hold_at, :processing_at, :completed_at, :refunded_at]
		end

		def self.DENORMALIZED_ORDER_ATTRIBUTES
			[:src_order_label, :src_order_id, :customer, :location, :billing_location, :shipping_location, :channel_partner, :campaign, :source, :wholesale_client]
		end


		# Methods
		# **************************************************************************

		# Abstract Methods
		# def extract_id_from_src_refund( src_refund )
		# def extract_state_attributes_from_src_refund( src_refund )
		# def extract_order_from_src_refund( src_refund )
		# def extract_line_items_from_src_refund( src_refund, order_transaction_items )
		# def extract_aggregate_adjustments_from_src_refund( src_refund )
		# def extract_total_from_src_refund( src_refund )
		# def extract_id_from_src_order( src_order )
		# def extract_channel_partner_from_src_order( src_order )
		# def extract_location_from_src_order( src_order )
		# def extract_customer_from_src_order( src_order )
		# def extract_transaction_items_attributes_from_src_order( src_order )
		# def extract_coupon_uses_from_src_order( src_order, order )



		def process_order( src_order, data_src, event = nil )
			# puts "\nprocess_order"
			src_order = self.extract_additional_attributes_for_order( src_order )

			# puts "  process_order after extract_additional_attributes_for_order"

			src_order_id = self.extract_id_from_src_order( src_order )

			# puts "  process_order after extract_id_from_src_order"

			# active records to update
			transaction_items = TransactionItem.where( data_src: data_src, src_transaction_id: src_order_id )

			if transaction_items.present?

				self.process_order_update( src_order, data_src, transaction_items: transaction_items )

			else

				self.process_order_create( src_order, data_src )

			end

			src_refunds = self.extract_src_refunds_from_src_order( src_order )

			src_refunds.each do |src_refund|

				refund_transaction_items = self.process_refund( src_refund, data_src )

			end

			#order = Order.where( data_src: data_src, src_order_id: src_order_id ).first
			#transaction_items = TransactionItem.where( data_src: data_src, src_transaction_id: src_order_id )

			#transaction_items

		end

		def process_refund( src_refund, data_src )
			src_refund = self.extract_additional_attributes_for_refund( src_refund )

			src_transaction_id = self.extract_id_from_src_refund( src_refund )
			# puts "\n\nRefund #{src_transaction_id}"
			# puts JSON.pretty_generate src_refund

			refund_transaction_items = TransactionItem.refund.where( data_src: data_src, src_transaction_id: src_transaction_id ).to_a

			order = self.extract_order_from_src_refund( src_refund )
			unless order.present?
				puts "Unable to find order for src_transaction_id #{src_transaction_id}"
				return refund_transaction_items
			end

			state_attributes = self.extract_state_attributes_from_src_refund( src_refund )

			order_transaction_items = TransactionItem.where( data_src: order.data_src, src_transaction_id: order.src_order_id ).to_a

			transaction_items_attributes = self.transform_refund_into_transaction_items_attributes( src_refund, order_transaction_items )

			# if refund already exists, update the state attributes AND channel partner/commission
			if refund_transaction_items.present?
				# puts "  -> Already Refunded"
				refund_transaction_items.each do |refund_transaction_item|

					refund_transaction_item.attributes = state_attributes

					transaction_item_attributes = transaction_items_attributes.find{ |row| row[:src_line_item_id] == refund_transaction_item.src_line_item_id }
					order_transaction_item = order_transaction_items.find{ |oti| oti.src_line_item_id == refund_transaction_item.src_line_item_id }

					if transaction_item_attributes.present? && order_transaction_item.present?

						transaction_items_attributes.delete_at( transaction_items_attributes.index(transaction_item_attributes) )
						order_transaction_items.delete_at( order_transaction_items.index(order_transaction_item) )

						refund_transaction_item.channel_partner = order_transaction_item.channel_partner
						refund_transaction_item.commission = transaction_item_attributes[:commission]

					else

						message = "src_transaction_id: #{src_transaction_id} "
						message = "#{message}transaction_item_attributes Not found!!! " unless transaction_item_attributes.present?
						message = "#{message}order_transaction_item Not found!!! " unless order_transaction_item.present?

						raise Exception.new( "TransactionItem Update Error: #{message}" )

					end

					unless refund_transaction_item.save
						raise Exception.new( "TransactionItem Update Error: #{refund_transaction_item.errors.full_messages}" )
					end
				end

			else
				# puts "  -> Create"
				refund_transaction_items = []

				# set defaults and denormatized order data for all refunds
				# transaction items
				default_transaction_item_attributes = { transaction_type: 'refund', data_src: data_src, src_transaction_id: src_transaction_id }
				default_transaction_item_attributes.merge!( EcomEtl.extract_attributes_from_model( order, EcomEtl.DENORMALIZED_ORDER_ATTRIBUTES ) )

				# Create new refund transaction items
				transaction_items_attributes.each do |transaction_item_attributes|

					refund_transaction_item = TransactionItem.new( default_transaction_item_attributes )
					refund_transaction_item.attributes = transaction_item_attributes
					refund_transaction_item.attributes = state_attributes

					unless refund_transaction_item.save
						raise Exception.new( "TransactionItem Create Error: #{refund_transaction_item.errors.full_messages}" )
					end

					refund_transaction_items << refund_transaction_item

				end

				# puts "transaction_items_attributes #{transaction_items_attributes.count}"
				# puts "refund_transaction_items #{refund_transaction_items.count}"


				# Update order and order transaction items status and set refunded
				# at timestamp.
				order_refund_updates = { refunded_at: refund_transaction_items.first.src_created_at }
				order_refund_updates[:status] = 'refunded' unless order.cancelled?

				order.update( order_refund_updates )

				order_transaction_items.each do |order_transaction_item|
					order_transaction_item.update( order_refund_updates )
				end

			end

			refund_transaction_items

		end




		# Class Methods
		# **************************************************************************



		def self.distribute_quantities( amount_to_distribute, quantity )
			return Array.new(quantity) { |i| 0 } if amount_to_distribute == 0
			return [amount_to_distribute] if quantity == 1

			per_value = amount_to_distribute.to_f / quantity.to_f
			sum = per_value.floor * quantity
			difference = amount_to_distribute - sum

			inc = 1
			inc = -1 if difference < 0

			distribution = Array.new(quantity) { |i| per_value.floor }

			index = 0

			while( index < difference.abs )
				pos = index % distribution.count
				distribution[pos] = distribution[pos] + inc

				index = index + 1
			end

			distribution

		end

		def self.distribute_ratios( amount_to_distribute, ratios )
			return [] unless ratios.count > 0

			distribution = Array.new(ratios.count) { |i| (ratios[i] * amount_to_distribute).floor }
			difference = amount_to_distribute - distribution.sum

			inc = 1
			inc = -1 if difference < 0

			index = 0

			while( index < difference.abs )
				pos = index % distribution.count
				distribution[pos] = distribution[pos] + inc

				index = index + 1
			end

			distribution

		end


		def self.extract_attributes_from_model( model, attribute_names )
			attributes = {}
			attribute_names.each do |attribute_name|
				attributes[attribute_name.to_sym] = model.try(attribute_name)
			end

			attributes
		end

		def self.sum_key_values( hash, keys )
			hash.slice( *keys ).values.sum
		end



		protected

		def extract_additional_attributes_for_order( src_order )
			puts "Warning: default extract_additional_attributes_for_order"
			src_order
		end

		def extract_additional_attributes_for_refund( src_refund )
			puts "Warning: default extract_additional_attributes_for_refund"
			src_refund
		end

		def extract_order_label_from_order( src_order )
			puts "Warning: default extract_order_label_from_order"
			self.extract_id_from_src_order( src_order )
		end

		def extract_src_refunds_from_src_order( src_order )
			puts "Warning: default extract_src_refunds_from_src_order"
			[]
		end

		def extract_subscription_from_transaction_item( transaction_item, subscription_attributes )
			puts "Warning: default extract_subscription_from_transaction_item"
			nil
		end

		def extract_channel_partner_from_src_order( src_order )
			puts "Warning: default extract_channel_partner_from_src_order"
			nil
		end

		def extract_wholesale_client_from_src_order( src_order, args = {} )
			puts "Warning: default extract_wholesale_client_from_src_order"
			nil
		end

		def process_order_create( src_order, data_src, args = {} )

			transaction_items_attributes = self.extract_transaction_items_attributes_from_src_order( src_order )

			order = self.extract_order_from_src_order( src_order, data_src )

			denormalized_order_attributes 	= EcomEtl.extract_attributes_from_model( order, EcomEtl.DENORMALIZED_ORDER_ATTRIBUTES )
			order_state_attributes 			= EcomEtl.extract_attributes_from_model( order, EcomEtl.STATE_ATTRIBUTES )

			default_attributes = { data_src: data_src, src_transaction_id: order.src_order_id }
			default_attributes = default_attributes.merge( denormalized_order_attributes )
			default_attributes = default_attributes.merge( order_state_attributes )

			# puts "process_order_create #{order.src_order_id}"
			# puts "src_order"
			# puts JSON.pretty_generate src_order
			# puts "transaction_items_attributes"
			# puts JSON.pretty_generate transaction_items_attributes
			coupon_uses = self.extract_coupon_uses_from_src_order( src_order, order )

			transaction_items = []
			transaction_items_attributes.each do |transaction_item_attributes|

				subscription_attributes = transaction_item_attributes.delete(:subscription_attributes)

				transaction_item_attributes = default_attributes.merge( transaction_item_attributes )

				# Create new transaction item
				transaction_item = TransactionItem.new( transaction_item_attributes )

				unless transaction_item.save
					raise Exception.new( "TransactionItem Create Error: #{transaction_item.errors.full_messages}" )
				end

				subscription = self.extract_subscription_from_transaction_item( transaction_item, subscription_attributes )

				# inherit data from subscription, if it exists.
				if subscription.present?

					transaction_item.subscription 		= subscription
					transaction_item.channel_partner	= subscription.channel_partner if !subscription.deny_recurring_commissions

					transaction_item.save


					# increment recurrance count for recurring transactions
					subscription.increment!( :recurrance_count )
				end


				transaction_items << transaction_item

			end

			transaction_items

		end

		def process_order_update( src_order, data_src, args = {} )

			order = self.extract_order_from_src_order( src_order, data_src )

			denormalized_order_attributes	= EcomEtl.extract_attributes_from_model( order, EcomEtl.DENORMALIZED_ORDER_ATTRIBUTES - [:channel_partner] )
			order_state_attributes				= EcomEtl.extract_attributes_from_model( order, EcomEtl.STATE_ATTRIBUTES )

			default_attributes = denormalized_order_attributes.merge( order_state_attributes )

			transaction_items = args[:transaction_items] || TransactionItem.where( data_src: data_src, src_transaction_id: order.src_order_id )

			transaction_items_attributes = self.extract_transaction_items_attributes_from_src_order( src_order, data_src )

			remaining_transaction_items_attributes = transaction_items_attributes.dup

			coupon_uses = self.extract_coupon_uses_from_src_order( src_order, order )

			# puts "process_order_update #{order.src_order_id}"
			# puts "src_order"
			# puts JSON.pretty_generate src_order
			# puts "transaction_items.count #{transaction_items.count}"
			# puts "transaction_items_attributes"
			# puts JSON.pretty_generate transaction_items_attributes

			transaction_items.each do |transaction_item|

				index = remaining_transaction_items_attributes.index{ |item| item[:src_line_item_id] == transaction_item.src_line_item_id && item[:total] == transaction_item.total && item[:sub_total] == transaction_item.sub_total && item[:commission] == transaction_item.commission }
				index ||= remaining_transaction_items_attributes.index{ |item| item[:src_line_item_id] == transaction_item.src_line_item_id }

				if index.nil?
					puts "ERROR could not find attributes to perform update"
					puts "src_order"
					puts JSON.pretty_generate src_order
					puts "transaction_items_attributes"
					puts JSON.pretty_generate transaction_items_attributes
					puts "transaction_items"
					puts JSON.pretty_generate transaction_items.collect(&:attributes)
					return false
				end


				transaction_item_attributes = remaining_transaction_items_attributes.delete_at( index )

				transaction_item_attributes = default_attributes.merge( transaction_item_attributes )

				# if cancelled only add new values... do not zero out or nil any
				if order.cancelled?

					#puts "order.cancelled?"
					#puts JSON.pretty_generate src_order
					#puts JSON.pretty_generate transaction_item_attributes

					transaction_item_attributes = transaction_item_attributes.select do |attribute_name, attribute_value|
						attribute_value.present? && not( EcomEtl.NUMERIC_ATTRIBUTES.include?( attribute_name.to_sym ) )
					end

					#puts JSON.pretty_generate transaction_item_attributes

				end


				subscription_attributes = transaction_item_attributes.delete(:subscription_attributes)

				subscription = transaction_item.subscription


				# Create update transaction item's attributes
				transaction_item.attributes = transaction_item_attributes

				transaction_item.channel_partner ||= order.channel_partner

				if subscription.present?

					subscription.channel_partner ||= transaction_item.channel_partner
					subscription.deny_recurring_commissions ||= (subscription.channel_partner.try(:deny_recurring_commissions) || false)

					puts "subscription.changes #{subscription.changes.to_json}" if subscription.changes.present?
					subscription.save

				else

					subscription = self.extract_subscription_from_transaction_item( transaction_item, subscription_attributes )

					# inherit data from subscription, if it exists.
					if subscription.present?

						transaction_item.subscription 		= subscription
						transaction_item.channel_partner	= subscription.channel_partner if !subscription.deny_recurring_commissions

					end

				end

				if transaction_item.changes.present?

					puts "transaction_item.changes #{transaction_item.changes.to_json} #{transaction_item[:src_order_id]}"
					# puts JSON.pretty_generate src_order
					# puts JSON.pretty_generate transaction_item_attributes

				end

				unless transaction_item.save
					raise Exception.new( "TransactionItem Update Error: #{transaction_item.errors.full_messages}" )
				end


			end

			transaction_items

		end

		def transform_refund_into_transaction_items_attributes( src_refund, order_transaction_items )

			aggregate_adjustments = self.extract_aggregate_adjustments_from_src_refund( src_refund )

			refund_total	= self.extract_total_from_src_refund( src_refund )
			order_total 	= order_transaction_items.sum(&:total)

			if refund_total.abs == order_total.abs

				# Full Refund
				# puts " -- Full Refund -- "
				transaction_items_attributes = transform_full_refund_into_transaction_items_attributes( src_refund, order_transaction_items )

			else

				# Partial Refund
				# puts " -- Partial Refund -- "

				if ( line_items = self.extract_line_items_from_src_refund( src_refund, order_transaction_items ) ).present?
					# Partial Refund, with line items
					# puts " -- Partial Refund w/ Items -- "

					transaction_items_attributes = transform_items_refund_into_transaction_items_attributes( line_items, order_transaction_items, aggregate_adjustments )


				else
					# Partial Refund, without line items
					# puts " -- Partial Refund w/o Items -- "

					transaction_items_attributes = transform_amount_refund_into_transaction_items_attributes( order_transaction_items, refund_total, aggregate_adjustments )

				end


			end

			# puts "src_refund:"
			# puts JSON.pretty_generate src_refund
			# puts "transform_refund_into_transaction_items_attributes:"
			# puts JSON.pretty_generate transaction_items_attributes

			transaction_items_attributes
		end

		def extract_order_from_src_order( src_order, data_src, args = {} )
			state_attributes 	= self.extract_state_attributes_from_order( src_order )
			src_order_id 		= self.extract_id_from_src_order( src_order )

			order = Order.where( data_src: data_src, src_order_id: src_order_id ).first_or_initialize

			state_attributes.each do |attribute, value|
				order.try("#{attribute}=",value)
			end

			order.channel_partner		||= self.extract_channel_partner_from_src_order( src_order )
			order.location					||= self.extract_location_from_src_order( src_order )
			order.billing_location	||= self.extract_billing_location_from_src_order( src_order )
			order.shipping_location	||= self.extract_shipping_location_from_src_order( src_order )
			order.customer					= self.extract_customer_from_src_order( src_order )
			order.wholesale_client	||= self.extract_wholesale_client_from_src_order( src_order )
			order.src_order_label		||= self.extract_order_label_from_order( src_order )

			unless order.save
				raise Exception.new( "Order Create Error: #{order.errors.full_messages}" )
			end

			order
		end

		def correct_transaction_item_rounding_errors( transaction_item_attributes )
			calculated_total = 0

			# puts "transaction_item_attributes before corrections"
			# puts JSON.pretty_generate transaction_item_attributes

			EcomEtl.NUMERIC_ATTRIBUTES.each do |attribute_name|
				if EcomEtl.AGGREGATE_TOTAL_NUMERIC_ATTRIBUTES.include?(attribute_name)
					if EcomEtl.NEGATIVE_NUMERIC_ATTRIBUTES.include?(attribute_name)
						calculated_total -= transaction_item_attributes[attribute_name]
					else
						calculated_total += transaction_item_attributes[attribute_name]
					end
				end
			end

			total_delta = transaction_item_attributes[:total] - calculated_total

			# puts "correct_transaction_item_rounding_errors total_delta: #{total_delta} = #{transaction_item_attributes[:total]} - #{calculated_total}"
			# puts JSON.pretty_generate transaction_item_attributes

			# shuffle any rounding errors into misc discount, if discount present
			if transaction_item_attributes[:total_discount] != 0

				transaction_item_attributes[:misc_discount] -= total_delta

			# shuffle any rounding errors into tax, if tax present
			elsif transaction_item_attributes[:tax] != 0

				transaction_item_attributes[:tax] += total_delta

			# otherwise shuffle any rounding errors into amount
			else

				transaction_item_attributes[:amount] += total_delta

			end

			# Recalculate
			transaction_item_attributes[:total_discount] 	= EcomEtl.sum_key_values( transaction_item_attributes, EcomEtl.AGGREGATE_TOTAL_DISCOUNT_NUMERIC_ATTRIBUTES )
			transaction_item_attributes[:sub_total] 		= transaction_item_attributes[:amount] - transaction_item_attributes[:total_discount]


			# if total_delta != 0
			# 	puts "total_delta #{total_delta}"
			# 	puts JSON.pretty_generate transaction_item_attributes
			# else
			# 	puts "No Changes"
			# end

			transaction_item_attributes
		end

		def find_or_create_offer( data_src, options = {} )
			product_attributes	= options[:product_attributes] || {}
			product_attributes[:data_src] ||= data_src

			offer_attributes		= options[:offer_attributes] || {}
			offer_attributes[:data_src] ||= data_src


			raise Exception.new( "src_offer_id is blank for #{options.to_json}" ) if offer_attributes[:src_offer_id].blank?
			raise Exception.new( "src_product_id is blank for #{options.to_json}" ) if product_attributes[:src_product_id].blank?


			# Find offer by data_src and src_offer_id, or create with offer attributes
			offer = Offer.where(
				data_src: data_src,
				src_offer_id: offer_attributes[:src_offer_id]
			).create_with(
				offer_attributes.merge( offer_type: Offer.offer_types[ offer_attributes[:offer_type] ] )
			).first_or_create

			offer.product ||= Product.where(
				data_src: data_src,
				src_product_id: product_attributes[:src_product_id]
			).first
			offer.product ||= Product.create( product_attributes )
			offer.save

			# raise any fatal errors
			if offer.errors.present?
				Rails.logger.info offer.attributes.to_s
				raise Exception.new( offer.errors.full_messages )
			end

			offer

		end

		def transform_full_refund_into_transaction_items_attributes( src_refund, order_transaction_items )
			transaction_items_attributes = []

			order_transaction_items.each do |order_transaction_item|

				transaction_item_attributes = {
					src_subscription_id:		order_transaction_item.src_subscription_id,
					subscription: 					order_transaction_item.subscription,
					product:								order_transaction_item.product,
					offer:									order_transaction_item.offer,
					offer_type:							order_transaction_item.offer_type,
					subscription_interval:	order_transaction_item.subscription_interval,
					src_line_item_id:				order_transaction_item.src_line_item_id,
					warehouse:							order_transaction_item.warehouse,
					merchant_processor:			order_transaction_item.merchant_processor,
					currency:								order_transaction_item.currency,
					amount: 								-order_transaction_item.amount,
					misc_discount: 					-order_transaction_item.misc_discount,
					coupon_discount: 				-order_transaction_item.coupon_discount,
					total_discount: 				-order_transaction_item.total_discount,
					sub_total: 							-order_transaction_item.sub_total,
					shipping: 							-order_transaction_item.shipping,
					shipping_tax: 					-order_transaction_item.shipping_tax,
					tax: 										-order_transaction_item.tax,
					adjustment: 						-order_transaction_item.adjustment,
					total: 									-order_transaction_item.total,
				}

				transaction_item_attributes[:commission] = -order_transaction_item.commission unless order_transaction_item.commission.nil?

				transaction_items_attributes << transaction_item_attributes

			end

			transaction_items_attributes
		end

		def transform_items_refund_into_transaction_items_attributes( line_items, order_transaction_items, aggregate_adjustments={} )
			transaction_items_attributes = []
			line_items = line_items.collect(&:symbolize_keys)

			total = line_items.sum{ |item| item[:total] }

			if total == 0
				ratios = line_items.collect{ |item| 0 }
			else
				ratios = line_items.collect{ |item| item[:total] / total.to_f }
			end

			distributed_aggregate_adjustments = line_items.collect{|line_item| {} }
			aggregate_adjustments.each do |attribute_name, attribute_value|
				EcomEtl.distribute_ratios( attribute_value, ratios ).each_with_index do |value, index|

					distributed_aggregate_adjustments[index][attribute_name.to_sym] = value
				end
			end

			line_items.each_with_index do |line_item, line_item_index|

				transaction_items 	= order_transaction_items.select{ |item| item.src_line_item_id == line_item[:src_line_item_id] }
				quantity 			= line_item[:quantity]

				line_item_adjustments = distributed_aggregate_adjustments[line_item_index]


				line_item_numerics = {}
				EcomEtl.NUMERIC_ATTRIBUTES.each do |numeric_attribute_name|
					line_item_numerics[numeric_attribute_name] = (line_item[numeric_attribute_name] || 0) + ( line_item_adjustments[numeric_attribute_name] || 0 )
				end

				# distributed values
				distributed_numerics = {}
				line_item_numerics.each do |attribute_name,attribute_value|
					distributed_numerics[attribute_name] = EcomEtl.distribute_quantities( attribute_value, quantity )
				end


				# only process refunds for up to the quantity refunded.
				transaction_items[0..(quantity-1)].each_with_index do |order_transaction_item, index|

					transaction_item_attributes = {
						src_subscription_id: 		order_transaction_item.src_subscription_id,
						subscription: 					order_transaction_item.subscription,
						product:								order_transaction_item.product,
						offer:									order_transaction_item.offer,
						subscription_interval:	order_transaction_item.subscription_interval,
						offer_type:							order_transaction_item.offer_type,
						src_line_item_id:				order_transaction_item.src_line_item_id,
						currency:								order_transaction_item.currency,
						warehouse:							order_transaction_item.warehouse,
						merchant_processor:			order_transaction_item.merchant_processor,
					}

					EcomEtl.NUMERIC_ATTRIBUTES.each do |attribute_name|
						transaction_item_attributes[attribute_name] = distributed_numerics[attribute_name][index]
					end

					# puts "Before Corrections"
					# puts JSON.pretty_generate transaction_item_attributes

					correct_transaction_item_rounding_errors( transaction_item_attributes )

					# puts "After Corrections"
					# puts JSON.pretty_generate transaction_item_attributes

					transaction_items_attributes << transaction_item_attributes

				end

			end

			transaction_items_attributes
		end

		def transform_amount_refund_into_transaction_items_attributes( order_transaction_items, refund_total, args = {} )
			log_string = ""

			transaction_items_attributes = []

			order_transaction_items = order_transaction_items.to_a

			charge_total = order_transaction_items.sum{ |item| item.try(:total) }
			ratios_of_totals = order_transaction_items.collect{ |item| item.try(:total) / charge_total.abs.to_f }

			refund_percent = refund_total.to_f / charge_total.to_f

			# puts "refund_total #{refund_total}"
			# puts "charge_total #{charge_total}"
			# puts "ratios_of_totals"
			# puts JSON.pretty_generate( ratios_of_totals )
			# puts "refund_percent #{refund_percent}"

			# distribute the total and any specified refund amounts proproptionately
			# between transaction items
			distributed_attributes = {
				total: EcomEtl.distribute_ratios( refund_total, ratios_of_totals ),
			}
			args.each do |attribute_name, attribute_value|
				distributed_attributes[attribute_name] = EcomEtl.distribute_ratios( attribute_value, ratios_of_totals )
			end

			order_transaction_items.each_with_index do |order_transaction_item, index|
				order_transaction_item_attributes_was = order_transaction_item.attributes.merge({}).symbolize_keys
				order_transaction_item_attributes = order_transaction_item.attributes.merge({}).symbolize_keys

				transaction_item_attributes = {
					src_subscription_id: 		order_transaction_item.src_subscription_id,
					subscription: 					order_transaction_item.subscription,
					product:								order_transaction_item.product,
					offer:									order_transaction_item.offer,
					subscription_interval:	order_transaction_item.subscription_interval,
					offer_type:							order_transaction_item.offer_type,
					src_line_item_id:				order_transaction_item.src_line_item_id,
					currency:								order_transaction_item.currency,
					warehouse:							order_transaction_item.warehouse,
					merchant_processor:			order_transaction_item.merchant_processor,
				}

				# account for crazy data anomalies.  Work backwards.
				order_transaction_item_attributes[:sub_total] = order_transaction_item_attributes[:total] - order_transaction_item_attributes[:tax] - order_transaction_item_attributes[:shipping]
				if order_transaction_item_attributes_was[:sub_total].to_i != order_transaction_item_attributes[:sub_total].to_i
						puts "order_transaction_item_attributes.sub_total changed"
						puts " -> #{order_transaction_item_attributes_was[:sub_total]}"
						puts " -> #{order_transaction_item_attributes[:sub_total]}"
				end

				order_transaction_item_attributes[:amount] = order_transaction_item_attributes[:sub_total] + order_transaction_item_attributes[:total_discount]
				if order_transaction_item_attributes_was[:amount].to_i != order_transaction_item_attributes[:amount].to_i
						puts "order_transaction_item_attributes.amount changed"
						puts " -> #{order_transaction_item_attributes_was[:amount]}"
						puts " -> #{order_transaction_item_attributes[:amount]}"
				end


				log_string += "order_transaction_item.src_order_id #{order_transaction_item.src_order_id}\n"
				EcomEtl.NUMERIC_ATTRIBUTES.each do |attribute_name|

					# if an static amount was specified for this refund, then use it,
					# otherwise use the refund percent to determine the amount.
					if distributed_attributes[attribute_name].present?
						attribute_value = -distributed_attributes[attribute_name][index].abs
						log_string += "#{attribute_name}: #{attribute_value} (distributed)      #{order_transaction_item_attributes[attribute_name]}\n"
					else
						attribute_value = -(refund_percent * order_transaction_item_attributes[attribute_name].to_f).to_i.abs
						log_string += "#{attribute_name}: #{attribute_value} (percent)     #{refund_percent} * #{order_transaction_item_attributes[attribute_name].to_f}\n"
					end


					transaction_item_attributes[attribute_name] = attribute_value

				end

				correct_transaction_item_rounding_errors( transaction_item_attributes )

				transaction_items_attributes << transaction_item_attributes

			end

			# verify that all fields for a refund are negative
			begin
				transaction_items_attributes.each do |transaction_item_attributes|
					EcomEtl.POSITIVE_NUMERIC_ATTRIBUTES.each do |attr|
						raise Exception.new("#{attr} should be negative on a refund #{order_transaction_items.collect(&:src_order_id)}") unless transaction_item_attributes[attr] <= 0
					end

					raise Exception.new("amount (#{transaction_item_attributes[:amount]}) - discount (#{transaction_item_attributes[:total_discount]}) does not equal sub_total (#{transaction_item_attributes[:sub_total]}) on a refund #{order_transaction_items.collect(&:src_order_id)}") unless ((transaction_item_attributes[:amount] - transaction_item_attributes[:total_discount]) - transaction_item_attributes[:sub_total]).abs <= 5
					raise Exception.new("sub_total (#{transaction_item_attributes[:sub_total]}) + shipping (#{transaction_item_attributes[:shipping]}) + taxes (#{transaction_item_attributes[:tax]}) does not equal total (#{transaction_item_attributes[:total]}) on a refund #{order_transaction_items.collect(&:src_order_id)}") unless ((transaction_item_attributes[:sub_total] + transaction_item_attributes[:shipping] + transaction_item_attributes[:tax]) - transaction_item_attributes[:total]).abs <= 5

				end

				raise Exception.new("total expected is different than sum #{refund_total} != #{transaction_items_attributes.sum{|transaction_item_attributes| transaction_item_attributes[:total] }} on a refund #{order_transaction_items.collect(&:src_order_id)}") unless refund_total != transaction_items_attributes.sum{|transaction_item_attributes| transaction_item_attributes[:total] }
			rescue Exception => e
				puts e.message
				puts JSON.pretty_generate( order_transaction_items.collect(&:attributes) )
				puts JSON.pretty_generate( transaction_items_attributes )
				puts log_string

				raise e
			end

			transaction_items_attributes
		end

	end
end

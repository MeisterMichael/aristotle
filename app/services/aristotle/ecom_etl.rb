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

					refund_transaction_skus = refund_transaction_item.transaction_skus.to_a
					refund_transaction_item.attributes = state_attributes

					transaction_item_attributes = transaction_items_attributes.find{ |row| row[:src_line_item_id] == refund_transaction_item.src_line_item_id }
					order_transaction_item = order_transaction_items.find{ |oti| oti.src_line_item_id == refund_transaction_item.src_line_item_id }

					if transaction_item_attributes.present? && order_transaction_item.present?

						transaction_items_attributes.delete_at( transaction_items_attributes.index(transaction_item_attributes) )
						order_transaction_items.delete_at( order_transaction_items.index(order_transaction_item) )

						refund_transaction_item.channel_partner = order_transaction_item.channel_partner
						refund_transaction_item.commission = transaction_item_attributes[:commission]

						refund_transaction_skus.each do |refund_transaction_sku|
							refund_transaction_sku.channel_partner = order_transaction_item.channel_partner
							refund_transaction_sku.commission = transaction_item_attributes[:commission]
						end

					else

						message = "src_transaction_id: #{src_transaction_id} "
						message = "#{message}transaction_item_attributes Not found!!! " unless transaction_item_attributes.present?
						message = "#{message}order_transaction_item Not found!!! " unless order_transaction_item.present?

						raise Exception.new( "TransactionItem Update Error: #{message}" )

					end

					puts "refund_transaction_item.changes #{refund_transaction_item.changes.to_json} #{refund_transaction_item.src_order_id}" if refund_transaction_item.changes.present?

					unless refund_transaction_item.save
						raise Exception.new( "TransactionItem Update Error: #{refund_transaction_item.errors.full_messages}" )
					end


					refund_transaction_skus.each do |refund_transaction_sku|
						puts "refund_transaction_sku.changes #{refund_transaction_sku.changes.to_json} #{refund_transaction_sku.src_order_id}" if refund_transaction_sku.changes.present?

						unless refund_transaction_sku.save
							raise Exception.new( "TransactionSku Update Error: #{refund_transaction_sku.errors.full_messages}" )
						end
					end

				end

			else
				# puts "  -> Create"
				refund_transaction_items = []
				refund_transaction_skus = []

				# set defaults and denormatized order data for all refunds
				# transaction items
				default_transaction_item_attributes = { transaction_type: 'refund', data_src: data_src, src_transaction_id: src_transaction_id }
				default_transaction_item_attributes.merge!( EcomEtl.extract_attributes_from_model( order, EcomEtl.DENORMALIZED_ORDER_ATTRIBUTES ) )

				# Create new refund transaction items
				transaction_items_attributes.each do |transaction_item_attributes|
					transaction_skus_attributes = transaction_item_attributes.delete(:transaction_skus_attributes)

					refund_transaction_item = TransactionItem.new( default_transaction_item_attributes )
					refund_transaction_item.attributes = transaction_item_attributes
					refund_transaction_item.attributes = state_attributes

					unless refund_transaction_item.save
						raise Exception.new( "TransactionItem Create Error: #{refund_transaction_item.errors.full_messages}" )
					end

					refund_transaction_items << refund_transaction_item

					transaction_skus_attributes.each do |transaction_sku_attributes|

						refund_transaction_sku = TransactionSku.new( default_transaction_item_attributes )
						refund_transaction_sku.attributes = transaction_item_attributes
						refund_transaction_sku.attributes = transaction_sku_attributes
						refund_transaction_sku.attributes = state_attributes
						refund_transaction_sku.transaction_item = refund_transaction_item

						unless refund_transaction_sku.save
							raise Exception.new( "TransactionSku Create Error: #{refund_transaction_sku.errors.full_messages}" )
						end

						refund_transaction_skus << refund_transaction_sku

					end

				end

				# puts "transaction_items_attributes #{transaction_items_attributes.count}"
				# puts "refund_transaction_items #{refund_transaction_items.count}"


				# Update order and order transaction items status and set refunded
				# at timestamp.
				order_refund_updates = { refunded_at: refund_transaction_items.first.src_created_at } if refund_transaction_items.present?
				order_refund_updates[:status] = 'refunded' unless order.cancelled?

				order.update( order_refund_updates )

				order_transaction_items.each do |order_transaction_item|
					order_transaction_item.update( order_refund_updates )
				end

			end

			refund_transaction_items

		end


		def process_review( src_review, data_src, event = nil )
			product		= transform_src_review_to_product( src_review )
			offer			= transform_src_review_to_offer( src_review )
			customer	= extract_customer_from_src_review( src_review )

			review = Review.where( data_src: data_src, src_review_id: src_review[:id] ).first
			review ||= Review.new
			review.data_src	= data_src
			review.product	= product
			review.offer		= offer
			review.customer	= customer
			review.location	= customer.location

			review.src_review_id	= src_review[:id]
			review.status					= src_review[:status]
			review.referrer_src		= src_review[:referrer_src]
			review.reviewed_at		= src_review[:created_at]
			review.rating					= src_review[:rating]
			review.review_words		= src_review[:review_words]

			# puts review.attributes.to_json

			unless review.save
				raise Exception.new( "Review Create Error: #{review.errors.full_messages}" )
			end

			review
		end


		def transaction_item_skus_from_offer( offer, options = {} )
			time = options[:time] || Time.now

			transaction_skus_attributes = []
			offer.offer_skus.where( ":time >= started_at AND ( ended_at IS NULL OR :time <= ended_at )", time: time ).order('sku_id ASC').each do |offer_sku|
				offer_sku.sku_quantity.times do
					transaction_skus_attributes << { sku: offer_sku.sku, sku_value: offer_sku.sku_value }
				end
			end

			transaction_skus_attributes
		end

		def distribute_transaction_item_values_to_skus( transaction_item_attributes )

			sku_value_total = transaction_item_attributes[:transaction_skus_attributes].sum{|item| item[:sku_value] }.to_f
			sku_ratios = transaction_item_attributes[:transaction_skus_attributes].collect{|item| item[:sku_value].to_f / sku_value_total.to_f } if sku_value_total != 0
			sku_ratios = transaction_item_attributes[:transaction_skus_attributes].collect{|item| 1.0 } if sku_value_total == 0


			sku_distributed_amounts = EcomEtl.distribute_ratios( transaction_item_attributes[:amount], sku_ratios )
			sku_distributed_shipping_costs = EcomEtl.distribute_ratios( transaction_item_attributes[:shipping], sku_ratios )
			sku_distributed_commissions = EcomEtl.distribute_ratios( transaction_item_attributes[:commission] || 0, sku_ratios )
			sku_distributed_discounts = EcomEtl.distribute_ratios( transaction_item_attributes[:total_discount], sku_ratios )
			sku_distributed_tax = EcomEtl.distribute_ratios( transaction_item_attributes[:tax], sku_ratios )


			transaction_item_attributes[:transaction_skus_attributes].each_with_index do |transaction_sku_attributes, tsa_index|
				sku_ratio		= sku_ratios[tsa_index]

				sku_amount			= sku_distributed_amounts[tsa_index]
				sku_commissions	= sku_distributed_commissions[tsa_index]
				sku_discount		= sku_distributed_discounts[tsa_index]
				sku_shipping		= sku_distributed_shipping_costs[tsa_index]
				sku_tax					= sku_distributed_tax[tsa_index]


				transaction_sku_attributes.merge!(
					amount: sku_amount,
					commission: sku_commissions,
					misc_discount: sku_discount,
					coupon_discount: 0,
					total_discount: sku_discount,
					sub_total: sku_amount - sku_discount,
					shipping: sku_shipping,
					shipping_tax: 0,
					tax: sku_tax,
					adjustment: 0,
					total: sku_amount - sku_discount + sku_shipping + sku_tax,
				)
			end

			transaction_item_attributes[:transaction_skus_attributes]
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
				transaction_skus_attributes = transaction_item_attributes.delete(:transaction_skus_attributes)

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

				transaction_skus = process_order_transaction_skus( transaction_item, transaction_item_attributes, transaction_skus_attributes )
			end

			transaction_items

		end

		def process_order_update( src_order, data_src, args = {} )

			order = self.extract_order_from_src_order( src_order, data_src )

			denormalized_order_attributes	= EcomEtl.extract_attributes_from_model( order, EcomEtl.DENORMALIZED_ORDER_ATTRIBUTES - [:channel_partner] )
			order_state_attributes				= EcomEtl.extract_attributes_from_model( order, EcomEtl.STATE_ATTRIBUTES )

			default_attributes = { data_src: data_src, src_transaction_id: order.src_order_id }
			default_attributes = default_attributes.merge( denormalized_order_attributes )
			default_attributes = default_attributes.merge( order_state_attributes )

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
				transaction_skus_attributes = transaction_item_attributes.delete(:transaction_skus_attributes)

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


				process_order_transaction_skus( transaction_item, transaction_item_attributes, transaction_skus_attributes )

			end

			transaction_items

		end

		def process_order_transaction_skus( transaction_item, transaction_item_attributes, transaction_skus_attributes, args = {} )

			transaction_skus = transaction_item.transaction_skus

			if transaction_skus.present?

				# puts "process_order_transaction_skus UPDATE src_line_item_id: #{transaction_item.src_line_item_id}, data_src: #{transaction_item.data_src}, src_transaction_id: #{transaction_item.src_transaction_id}, offer: #{transaction_item.offer}, transaction_type: #{transaction_item.transaction_type}"
				# puts " -> #{transaction_skus_attributes.count}"

				transaction_skus.each do |transaction_sku|

					# puts " -> sku_id: #{transaction_sku.sku_id},  src_line_item_id: #{transaction_sku.src_line_item_id}, data_src: #{transaction_sku.data_src}, src_transaction_id: #{transaction_sku.src_transaction_id}, offer: #{transaction_sku.offer}, transaction_type: #{transaction_sku.transaction_type}"

					transaction_sku_attributes_index = transaction_skus_attributes.index{ |transaction_sku_attributes| transaction_sku_attributes[:sku] == transaction_sku.sku }
					transaction_sku_attributes = transaction_skus_attributes.delete_at( transaction_sku_attributes_index ) unless transaction_sku_attributes_index.nil?

					if @transaction_sku_require_sku_attributes
						raise Exception.new("Could not find sku match for transaction sku #{transaction_sku.id}") if transaction_sku_attributes_index.nil?
						raise Exception.new("Could not find attribute match for transaction sku #{transaction_sku.id}") if transaction_sku_attributes.blank?
					end

					# puts "   -> #{transaction_item_attributes.to_json}"
					# puts "   -> #{transaction_sku_attributes.to_json}"

					transaction_sku.attributes = transaction_item_attributes
					transaction_sku.attributes = transaction_sku_attributes if transaction_sku_attributes.present?

					puts "transaction_sku.changes #{transaction_sku.changes.to_json}" if transaction_sku.changes.present?

					unless transaction_sku.save
						raise Exception.new( "TransactionSku Update Error: #{transaction_sku.errors.full_messages}" )
					end

				end

			else
				# puts "process_order_transaction_skus CREATE src_line_item_id: #{transaction_item.src_line_item_id}, data_src: #{transaction_item.data_src}, src_transaction_id: #{transaction_item.src_transaction_id}, offer: #{transaction_item.offer}, transaction_type: #{transaction_item.transaction_type}"
				# puts " -> #{transaction_skus_attributes.count}"
				transaction_skus = []

				transaction_skus_attributes.each do |transaction_sku_attributes|
					transaction_sku = TransactionSku.new( transaction_item_attributes )
					transaction_sku.attributes = transaction_sku_attributes
					transaction_sku.transaction_item = transaction_item

					unless transaction_sku.save
						raise Exception.new( "TransactionSku Create Error: #{transaction_sku.errors.full_messages}" )
					end

					# puts " -> sku_id: #{transaction_sku.sku_id},  src_line_item_id: #{transaction_sku.src_line_item_id}, data_src: #{transaction_sku.data_src}, src_transaction_id: #{transaction_sku.src_transaction_id}, offer: #{transaction_sku.offer}, transaction_type: #{transaction_sku.transaction_type}"

					transaction_skus << transaction_sku
				end
			end

			transaction_skus
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

		def extract_transaction_skus_attributes_from_transaction_item_attributes( transaction_item_attributes, sku_object_values )
			transaction_skus_attributes = []

			sku_value_total = sku_object_values.sum{|item| item[:sku_value] }.to_f
			sku_ratios = sku_object_values.collect{|item| item[:sku_value] / sku_value_total } if sku_value_total != 0
			sku_ratios = sku_object_values.collect{|item| 1.0 } if sku_value_total == 0

			sku_distributed_amounts = EcomEtl.distribute_ratios( transaction_item_attributes[:amount], sku_ratios )
			sku_distributed_shipping_costs = EcomEtl.distribute_ratios( transaction_item_attributes[:shipping], sku_ratios )
			sku_distributed_commissions = EcomEtl.distribute_ratios( transaction_item_attributes[:commission] || 0, sku_ratios )

			sku_distributed_shipping_taxes = EcomEtl.distribute_ratios( transaction_item_attributes[:shipping_tax], sku_ratios )
			sku_distributed_taxes = EcomEtl.distribute_ratios( transaction_item_attributes[:tax], sku_ratios )

			sku_distributed_coupon_discount = EcomEtl.distribute_ratios( transaction_item_attributes[:coupon_discount], sku_ratios )
			sku_distributed_misc_discount = EcomEtl.distribute_ratios( transaction_item_attributes[:misc_discount], sku_ratios )
			sku_distributed_discounts = []
			sku_distributed_coupon_discount.each_with_index do |coupon_discount,index|
				sku_distributed_discounts[index] = coupon_discount + sku_distributed_misc_discount[index]
			end

			sku_distributed_adjustments = EcomEtl.distribute_ratios( transaction_item_attributes[:adjustment], sku_ratios )


			sku_object_values.each_with_index do |sku_object_value,sku_value_index|
				transaction_sku_attributes = transaction_item_attributes.merge({
					sku:										sku_object_value[:sku],
					sku_value: 							sku_object_value[:sku_value],
					amount: 								sku_distributed_amounts[sku_value_index],
					misc_discount: 					sku_distributed_misc_discount[sku_value_index],
					coupon_discount: 				sku_distributed_coupon_discount[sku_value_index],
					total_discount: 				sku_distributed_discounts[sku_value_index],
					sub_total: 							sku_distributed_amounts[sku_value_index] - sku_distributed_discounts[sku_value_index],
					shipping: 							sku_distributed_shipping_costs[sku_value_index],
					shipping_tax: 					sku_distributed_shipping_taxes[sku_value_index],
					tax: 										sku_distributed_taxes[sku_value_index],
					adjustment: 						sku_distributed_adjustments[sku_value_index],
					total: 									sku_distributed_amounts[sku_value_index] - sku_distributed_discounts[sku_value_index] + sku_distributed_shipping_costs[sku_value_index] + sku_distributed_taxes[sku_value_index] + sku_distributed_adjustments[sku_value_index],
				})

				transaction_skus_attributes << transaction_sku_attributes
			end

			transaction_skus_attributes
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

		def find_or_create_product( data_src, options = {} )
			product_attributes	= options[:product_attributes] || {}
			product_attributes[:data_src] ||= data_src

			raise Exception.new( "src_product_id is blank for #{options.to_json}" ) if product_attributes[:src_product_id].blank?

			product ||= Product.where(
				data_src: data_src,
				src_product_id: product_attributes[:src_product_id]
			).first
			product ||= Product.create( product_attributes )

			# raise any fatal errors
			if product.errors.present?
				Rails.logger.info product.attributes.to_s
				raise Exception.new( product.errors.full_messages )
			end

			product

		end

		def find_or_create_sku( data_src, options = {} )
			raise Exception.new( "src_sku_id is blank for #{options.to_json}" ) if options[:src_sku_id].blank?

			# Find offer by data_src and src_offer_id, or create with offer attributes
			sku = Sku.where(
				data_src: data_src,
				src_sku_id: options[:src_sku_id]
			).create_with( options ).first_or_create


			# raise any fatal errors
			if sku.errors.present?
				Rails.logger.info sku.attributes.to_s
				raise Exception.new( sku.errors.full_messages )
			end

			sku

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
					commission:							0,
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

				order_transaction_skus = Aristotle::TransactionSku.where( src_line_item_id: order_transaction_item.src_line_item_id, data_src: order_transaction_item.data_src, src_transaction_id: order_transaction_item.src_transaction_id, offer: order_transaction_item.offer )
				transaction_item_attributes[:transaction_skus_attributes] = extract_transaction_skus_attributes_from_transaction_item_attributes( transaction_item_attributes, order_transaction_skus.collect{|ots| { sku: ots.sku, sku_value: -ots.sku_value } } )

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
					order_transaction_skus = Aristotle::TransactionSku.where( src_line_item_id: order_transaction_item.src_line_item_id, data_src: order_transaction_item.data_src, src_transaction_id: order_transaction_item.src_transaction_id, offer: order_transaction_item.offer )
					transaction_item_attributes[:transaction_skus_attributes] = extract_transaction_skus_attributes_from_transaction_item_attributes( transaction_item_attributes, order_transaction_skus.collect{|ots| { sku: ots.sku, sku_value: -ots.sku_value } } )

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

				order_transaction_skus = Aristotle::TransactionSku.where( src_line_item_id: order_transaction_item.src_line_item_id, data_src: order_transaction_item.data_src, src_transaction_id: order_transaction_item.src_transaction_id, offer: order_transaction_item.offer )
				transaction_item_attributes[:transaction_skus_attributes] = extract_transaction_skus_attributes_from_transaction_item_attributes( transaction_item_attributes, order_transaction_skus.collect{|ots| { sku: ots.sku, sku_value: -ots.sku_value } } )

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

require 'acts-as-taggable-array-on'

module Aristotle
	class TransactionItem < ApplicationRecord

		belongs_to :channel_partner, required: false
		belongs_to :customer, required: false
		belongs_to :location, required: false
		belongs_to :billing_location, required: false, class_name: 'Aristotle::Location'
		belongs_to :shipping_location, required: false, class_name: 'Aristotle::Location'
		belongs_to :offer, required: false
		belongs_to :order, required: false
		belongs_to :product, required: false
		belongs_to :subscription, required: false
		belongs_to :warehouse, required: false
		belongs_to :wholesale_client, required: false
		belongs_to :event, required: false

		has_many :transaction_skus

		acts_as_taggable_array_on :tags

		enum offer_type: { 'subscription' => 1, 'default' => 0, 'renewal' => 2 }
		enum payment_type: { 'no_payment_type' => 0, 'credit_card' => 1, 'paypal' => 2, 'amazon_payments' => 3, 'cash' => 4, 'cheque' => 5, 'bitpay' => 6 }
		enum status: { 'cancelled' => -2, 'failed' => -1, 'pending' => 0, 'pre_ordered' => 1, 'on_hold' => 8, 'processing' => 9, 'completed' => 10, 'refunded' => 11 }
		enum transaction_type: { 'charge' => 1, 'refund' => -1 }

		# validate :numeric_field_validation

		def self.has_completed
			where.not( completed_at: nil )
		end

		def self.direct # non-renewals and not referred by partner
			self.nonrenewals.where( channel_partner: nil )
		end

		def self.nonrenewals
			where.not( offer_type: 'renewal' )
		end

		def self.full_refund
			data_src_order_id_eqaution = "( aristotle_transaction_items.data_src || ' ' || aristotle_transaction_items.src_order_id )"

			where( "#{data_src_order_id_eqaution} IN (?)", TransactionItem.unscoped.group(:data_src, :src_order_id).having("SUM(aristotle_transaction_items.sub_total) = 0 AND SUM(ABS(aristotle_transaction_items.sub_total)) > 0").select("distinct #{data_src_order_id_eqaution}") )
		end

		def self.not_full_refund
			data_src_order_id_eqaution = "( aristotle_transaction_items.data_src || ' ' || aristotle_transaction_items.src_order_id )"

			where( "NOT( #{data_src_order_id_eqaution} IN (?) )", TransactionItem.unscoped.group(:data_src, :src_order_id).having("SUM(aristotle_transaction_items.sub_total) = 0 AND SUM(ABS(aristotle_transaction_items.sub_total)) > 0").select("distinct #{data_src_order_id_eqaution}") )
		end

		def self.upsell_impressions
			self.joins('INNER JOIN aristotle_upsell_impressions ON aristotle_upsell_impressions.order_id = aristotle_transaction_items.order_id AND aristotle_upsell_impressions.upsell_offer_id = aristotle_transaction_items.offer_id')
		end

		def numeric_field_validation( options = {} )
			options[:allowed_deviation] ||= 0

			numeric_fields = [ :amount, :misc_discount, :coupon_discount, :total_discount, :sub_total, :shipping, :shipping_tax, :tax, :total ]
			# :commission

			errors.add(:total_discount, "should be equal to misc_discount (#{misc_discount}) + coupon_discount (#{coupon_discount}), but it is not (#{total_discount})") if ( misc_discount.to_i + coupon_discount.to_i - total_discount.to_i ).abs > options[:allowed_deviation]
			errors.add(:sub_total, "should be equal to amount (#{amount}) - total_discount (#{total_discount}), but it is not (#{sub_total})") if ( amount.to_i - total_discount.to_i - sub_total.to_i ).abs > options[:allowed_deviation]
			errors.add(:total, "should be equal to sub_total (#{sub_total}) + tax (#{tax}) + shipping (#{shipping}), but it is not (#{total})") if ( sub_total.to_i + tax.to_i + shipping.to_i - total.to_i ).abs > options[:allowed_deviation]

			numeric_fields.each do |numeric_field|
				if self.try(numeric_field).nil?
					errors.add(numeric_field, "should not be empty")
				else
					errors.add(numeric_field, "must be greater than or equal to zero for a charge #{self.try(numeric_field)}") if charge? && self.try(numeric_field) < 0
					errors.add(numeric_field, "must be less than or equal to zero for a refund #{self.try(numeric_field)}") if refund? && self.try(numeric_field) > 0
				end
			end

		end

	end
end

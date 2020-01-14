module Aristotle
	class TransactionItem < ApplicationRecord

		belongs_to :channel_partner, required: false
		belongs_to :customer, required: false
		belongs_to :location, required: false
		belongs_to :offer, required: false
		belongs_to :product, required: false
		belongs_to :subscription, required: false
		belongs_to :wholesale_client, required: false

		enum offer_type: { 'subscription' => 1, 'default' => 0, 'renewal' => 2 }
		enum payment_type: { 'no_payment_type' => 0, 'credit_card' => 1, 'paypal' => 2, 'amazon_payments' => 3, 'cash' => 4, 'cheque' => 5, 'bitpay' => 6 }
		enum status: { 'cancelled' => -2, 'failed' => -1, 'pending' => 0, 'pre_ordered' => 1, 'on_hold' => 8, 'processing' => 9, 'completed' => 10, 'refunded' => 11 }
		enum transaction_type: { 'charge' => 1, 'refund' => -1 }

		def self.has_completed
			where.not( completed_at: nil )
		end

		def self.new_subscriptions
			joins(:offer).where( 'aristotle_offers.offer_type = :subscription_offer_type', subscription_offer_type: Offer.offer_types['subscription'] )
		end

		def self.direct # non-renewals and not referred by partner
			self.nonrenewals.where( channel_partner: nil )
		end

		def self.nonrenewals
			joins(:offer).where( 'aristotle_offers.offer_type = :subscription_offer_type OR aristotle_transaction_items.subscription_id IS NULL', subscription_offer_type: Offer.offer_types['subscription'] )
		end

		def self.renewals
			joins(:offer).where( 'NOT( aristotle_offers.offer_type = :subscription_offer_type ) AND aristotle_transaction_items.subscription_id IS NOT NULL', subscription_offer_type: Offer.offer_types['subscription'] )
		end

		def self.full_refund
			data_src_order_id_eqaution = "( aristotle_transaction_items.data_src || ' ' || aristotle_transaction_items.src_order_id )"

			where( "#{data_src_order_id_eqaution} IN (?)", TransactionItem.unscoped.group(:data_src, :src_order_id).having("SUM(aristotle_transaction_items.sub_total) = 0 AND SUM(ABS(aristotle_transaction_items.sub_total)) > 0").select("distinct #{data_src_order_id_eqaution}") )
		end

		def self.not_full_refund
			data_src_order_id_eqaution = "( aristotle_transaction_items.data_src || ' ' || aristotle_transaction_items.src_order_id )"

			where( "NOT( #{data_src_order_id_eqaution} IN (?) )", TransactionItem.unscoped.group(:data_src, :src_order_id).having("SUM(aristotle_transaction_items.sub_total) = 0 AND SUM(ABS(aristotle_transaction_items.sub_total)) > 0").select("distinct #{data_src_order_id_eqaution}") )
		end

	end
end

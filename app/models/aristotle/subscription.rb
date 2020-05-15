module Aristotle
	class Subscription < ApplicationRecord

			belongs_to :channel_partner, required: false
			belongs_to :customer, required: false
			belongs_to :location, required: false
			belongs_to :billing_location, required: false, class_name: 'Aristotle::Location'
			belongs_to :shipping_location, required: false, class_name: 'Aristotle::Location'
			belongs_to :offer, required: false
			belongs_to :product, required: false
			belongs_to :transaction_item, required: false
			belongs_to :wholesale_client, required: false

			enum status: { 'active' => 1, 'canceled' => -1, 'on_hold' => 0 }
			enum payment_type: { 'no_payment_type' => 0, 'credit_card' => 1, 'paypal' => 2, 'amazon_payments' => 3, 'cash' => 4, 'cheque' => 5, 'bitpay' => 6 }

	end
end

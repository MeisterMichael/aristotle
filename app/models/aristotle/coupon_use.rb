module Aristotle
	class CouponUse < ApplicationRecord

		belongs_to :coupon, required: false
		belongs_to :channel_partner, required: false
		belongs_to :customer, required: false
		belongs_to :location, required: false
		belongs_to :billing_location, required: false, class_name: 'Aristotle::Location'
		belongs_to :shipping_location, required: false, class_name: 'Aristotle::Location'
		# belongs_to :offer, required: false
		# belongs_to :product, required: false
		# belongs_to :subscription, required: false

	end
end

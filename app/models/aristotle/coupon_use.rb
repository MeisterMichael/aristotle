module Aristotle
	class CouponUse < ApplicationRecord

		belongs_to :coupon, required: false
		belongs_to :channel_partner, required: false
		belongs_to :customer, required: false
		belongs_to :location, required: false
		# belongs_to :offer, required: false
		# belongs_to :product, required: false
		# belongs_to :subscription, required: false

	end
end

module Aristotle
	class Coupon < ApplicationRecord

		enum discount_type: { 'percent' => 1, 'recurring_percent' => 2, 'fixed_cart' => 3, 'percent_product' => 4 }
		belongs_to :channel_partner, required: false

	end
end

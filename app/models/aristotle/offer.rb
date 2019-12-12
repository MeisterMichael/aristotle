module Aristotle
	class Offer < ApplicationRecord

		belongs_to :product, required: false
		enum offer_type: { 'subscription' => 1, 'default' => 0, 'renewal' => 2 }

	end
end

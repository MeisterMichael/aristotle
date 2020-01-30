module Aristotle
	class OfferSetProduct < ApplicationRecord
		belongs_to :offer_set
		belongs_to :product
	end
end

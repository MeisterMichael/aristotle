module Aristotle
	class OfferSetOffer < ApplicationRecord
		belongs_to :offer_set
		belongs_to :offer
	end
end

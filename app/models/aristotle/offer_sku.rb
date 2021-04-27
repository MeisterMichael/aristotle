module Aristotle
	class OfferSku < ApplicationRecord

		belongs_to :offer
		belongs_to :sku

		# sku_value
		# sku_quantity
		# started_at
		# ended_at

	end
end

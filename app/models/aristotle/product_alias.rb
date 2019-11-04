module Aristotle
	class ProductAlias < ApplicationRecord

		belongs_to :product, required: false

	end
end

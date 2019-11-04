module Aristotle
	class Product < ApplicationRecord

		has_many :offers
		has_many :product_aliases

		enum status: { 'active' => 1, 'draft' => 0 }

	end
end

module Aristotle
	class Warehouse < ApplicationRecord

		has_many :transaction_items

	end
end

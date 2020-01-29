module Aristotle
	class Product < ApplicationRecord

		has_many :offers

		enum status: { 'active' => 1, 'draft' => 0, 'unused' => -1 }

	end
end

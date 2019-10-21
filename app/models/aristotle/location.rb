module Aristotle
	class Location < ApplicationRecord
		def to_s
			"#{city}, #{state_code} #{zip} #{country_code}"
		end
	end
end

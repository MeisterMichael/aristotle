module Aristotle
	class CurrencyExchange < ApplicationRecord

		def self.find_rate( from, to )
			rate = CurrencyExchange.where( from_currency: from, to_currency: to ).first.try(:rate)

			if rate.nil? && ( inverse_rate = CurrencyExchange.where( from_currency: to, to_currency: from ).first.try(:rate) )
				rate = 1 / inverse_rate
			end

			rate
		end

	end
end

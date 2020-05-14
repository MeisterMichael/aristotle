module Aristotle
	class CurrencyExchange < ApplicationRecord

		def self.find_rate( from, to, options = {} )
			options[:at] ||= Time.now

			from_to_currency_exchanges = CurrencyExchange.where( from_currency: from, to_currency: to )
			to_from_currency_exchanges = CurrencyExchange.where( from_currency: to, to_currency: from )

			rate = from_to_currency_exchanges.where('created_at <= ?', options[:at]).order(created_at: :desc).first.try(:rate)
			if rate.nil? && ( inverse_rate = to_from_currency_exchanges.where('created_at <= ?', options[:at]).order(created_at: :desc).first.try(:rate) )
				rate = 1 / inverse_rate
			end

			rate ||= from_to_currency_exchanges.where('created_at > ?', options[:at]).order(created_at: :asc).first.try(:rate)
			if rate.nil? && ( inverse_rate = to_from_currency_exchanges.where('created_at > ?', options[:at]).order(created_at: :asc).first.try(:rate) )
				rate = 1 / inverse_rate
			end

			rate
		end

	end
end

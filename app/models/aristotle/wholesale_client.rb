module Aristotle
	class WholesaleClient < ApplicationRecord

		has_many :orders
		has_many :transaction_items

		belongs_to :customer, required: false
		belongs_to :location, required: false

		def self.where_email( email )
			all.where( "lower(email) = :email", email: email.downcase )
		end

	end
end

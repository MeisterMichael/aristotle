module Aristotle
	class WholesaleClient < ApplicationRecord

		has_many :orders
		has_many :transaction_items

		belongs_to :customer, required: false
		belongs_to :location, required: false
		belongs_to :billing_location, required: false, class_name: 'Aristotle::Location'
		belongs_to :shipping_location, required: false, class_name: 'Aristotle::Location'

		def self.where_email( email )
			all.where( "lower(email) = :email", email: email.downcase )
		end

	end
end

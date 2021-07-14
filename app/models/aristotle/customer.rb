module Aristotle
	class Customer < ApplicationRecord

		belongs_to :location, required: false
		belongs_to :billing_location, required: false, class_name: 'Aristotle::Location'
		belongs_to :shipping_location, required: false, class_name: 'Aristotle::Location'
		has_many :orders
		has_many :transaction_items

		enum status: { 'redacted' => -100, 'guest' => 0, 'active' => 1, 'suspended' => 2 }

		def self.where_email( email )
			all.where( "lower(email) = :email", email: email.downcase )
		end

	end
end

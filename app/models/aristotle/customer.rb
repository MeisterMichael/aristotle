module Aristotle
	class Customer < ApplicationRecord

		belongs_to :location, required: false
		has_many :orders
		has_many :transaction_items

		enum status: { 'guest' => 0, 'active' => 1, 'suspended' => 2 }

		def self.where_email( email )
			all.where( "lower(email) = :email", email: email.downcase )
		end

	end
end

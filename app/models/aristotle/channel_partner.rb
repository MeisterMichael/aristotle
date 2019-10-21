module Aristotle
	class ChannelPartner < ApplicationRecord

		belongs_to 	:location, required: false
		belongs_to 	:parent, required: false, class_name: 'ChannelPartner'
		has_many	:recruits, class_name: 'ChannelPartner', foreign_key: 'parent_id'
		has_many	:transaction_items
		enum status: { 'active' => 1, 'suspended' => 2 }


		def self.recruiter
			where( id: ChannelPartner.unscoped.select( 'distinct parent_id' ) )
		end

		def recruiter?
			self.recruits.present?
		end

	end
end

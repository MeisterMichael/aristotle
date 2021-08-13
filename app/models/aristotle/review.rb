module Aristotle
	class Review < ApplicationRecord

		belongs_to :customer, required: false
		belongs_to :location, required: false
		belongs_to :offer, required: false
		belongs_to :product, required: false

		enum status: { 'trash' => -50, 'removed' => -20, 'compliance_review' => -15, 'to_moderate' => -10, 'draft' => 0, 'active' => 1 }


	end
end

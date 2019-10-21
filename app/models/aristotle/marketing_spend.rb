module Aristotle
	class MarketingSpend < ApplicationRecord

		# belongs_to :campaign, required: false
		belongs_to :email_campaign, required: false
		enum purpose: { 'spend' => 0, 'research' => 1 }


	end
end

module Aristotle
	class Order < ApplicationRecord

		belongs_to :channel_partner, required: false
		belongs_to :customer, required: false
		belongs_to :location, required: false
		belongs_to :wholesale_client, required: false

		enum status: { 'cancelled' => -2, 'failed' => -1, 'pending' => 0, 'pre_ordered' => 1, 'on_hold' => 8, 'processing' => 9, 'completed' => 10, 'refunded' => 11 }


	end
end

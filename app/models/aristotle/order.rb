require 'acts-as-taggable-array-on'

module Aristotle
	class Order < ApplicationRecord

		belongs_to :channel_partner, required: false
		belongs_to :customer, required: false
		belongs_to :location, required: false
		belongs_to :billing_location, required: false, class_name: 'Aristotle::Location'
		belongs_to :shipping_location, required: false, class_name: 'Aristotle::Location'
		belongs_to :wholesale_client, required: false
		belongs_to :aristotle_event, required: false, class_name: 'Aristotle::Event'

		acts_as_taggable_array_on :tags

		enum status: { 'cancelled' => -2, 'failed' => -1, 'pending' => 0, 'pre_ordered' => 1, 'on_hold' => 8, 'processing' => 9, 'completed' => 10, 'refunded' => 11 }


	end
end

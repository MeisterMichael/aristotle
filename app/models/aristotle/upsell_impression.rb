require 'acts-as-taggable-array-on'

module Aristotle
	class UpsellImpression < ApplicationRecord

		belongs_to :customer, required: false
		belongs_to :from_offer, required: false, class_name: 'Aristotle::Offer'
		belongs_to :from_product, required: false, class_name: 'Aristotle::Product'
		belongs_to :upsell_offer, required: false, class_name: 'Aristotle::Offer'
		belongs_to :upsell_product, required: false, class_name: 'Aristotle::Product'
		belongs_to :impression_event, required: false, class_name: 'Aristotle::Event'
		belongs_to :accepted_event, required: false, class_name: 'Aristotle::Event'
		belongs_to :purchase_event, required: false, class_name: 'Aristotle::Event'
		belongs_to :order, required: false

		# event_data_src
		# src_client_id
		# src_created_at
		# accepted_at
		# order_data_src
		# src_order_id

	end
end

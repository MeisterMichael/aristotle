module Aristotle
	class Event < ApplicationRecord
		belongs_to :channel_partner, required: false
		belongs_to :coupon, required: false
		belongs_to :customer, required: false
		belongs_to :email_campaign, required: false
		belongs_to :location, required: false
		belongs_to :offer, required: false
		belongs_to :order, required: false
		belongs_to :product, required: false
		belongs_to :subscription, required: false
		belongs_to :wholesale_client, required: false


	end
end

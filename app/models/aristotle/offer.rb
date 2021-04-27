require 'acts-as-taggable-array-on'

module Aristotle
	class Offer < ApplicationRecord

		belongs_to :product, required: false
		has_many :offer_set_offers
		has_many :offer_skus

		enum offer_type: { 'subscription' => 1, 'default' => 0, 'renewal' => 2 }

		acts_as_taggable_array_on :tags


		def offer_set_ids
			offer_set_offers.pluck(:offer_set_id)
		end

		def offer_set_ids=( ids )
			offer_set_offers.where.not( offer_set_id: ids ).destroy_all
			ids.select(&:present?).each do |id|
				offer_set_offers.where( offer_set_id: id ).first_or_create
			end

			ids
		end


		def tags_csv
			tags.join(',')
		end

		def tags_csv=(str)
			self.tags = str.split(',')
		end

	end
end

require 'acts-as-taggable-array-on'

module Aristotle
	class Offer < ApplicationRecord

		belongs_to :product, required: false
		enum offer_type: { 'subscription' => 1, 'default' => 0, 'renewal' => 2 }

		acts_as_taggable_array_on :tags

		def tags_csv
			tags.join(',')
		end

		def tags_csv=(str)
			self.tags = str.split(',')
		end

	end
end

module Aristotle
	class Product < ApplicationRecord

		has_many :offers
		has_many :offer_set_products

		enum status: { 'active' => 1, 'draft' => 0, 'unused' => -1 }

		def offer_set_ids
			offer_set_products.pluck(:offer_set_id)
		end

		def offer_set_ids=( ids )
			offer_set_products.where.not( offer_set_id: ids ).destroy_all
			ids.select(&:present?).each do |id|
				offer_set_products.where( offer_set_id: id ).first_or_create
			end

			ids
		end

	end
end

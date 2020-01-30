require 'acts-as-taggable-array-on'

module Aristotle
	class OfferSet < ApplicationRecord

		has_many :offer_set_offers
		has_many :offer_set_products

		has_many :offers, through: :offer_set_offers

		acts_as_taggable_array_on :tags

		def all_offers
			offers = Offer.joins(:offer_set_offers).merge( self.offer_set_offers )
			offers = offers.or( Offer.joins(:product).merge( Product.joins(:offer_set_products).merge( self.offer_set_products ) ) )
			offers
		end

		def self.all_offers
			offer_sets = self.all

			offers = Offer.where( id: OfferSetOffer.joins(:offer_set).merge( offer_sets ).select(:offer_id) )
			offers = offers.or( Offer.where( id: OfferSetProduct.joins(:offer_set).merge( offer_sets ).select(:product_id) ) )
			offers
		end


		def offer_ids
			offer_set_offers.pluck(:offer_id)
		end

		def offer_ids=( ids )
			offer_set_offers.where.not( offer_id: ids ).destroy_all
			ids.select(&:present?).each do |id|
				offer_set_offers.where( offer_id: id ).first_or_create
			end

			ids
		end


		def product_ids
			offer_set_products.pluck(:product_id)
		end

		def product_ids=( ids )
			offer_set_products.where.not( product_id: ids ).destroy_all
			ids.select(&:present?).each do |id|
				offer_set_products.where( product_id: id ).first_or_create
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

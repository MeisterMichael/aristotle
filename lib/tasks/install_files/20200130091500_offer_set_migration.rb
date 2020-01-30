class OfferSetMigration < ActiveRecord::Migration[5.1]
	def change

		create_table :aristotle_offer_sets do |t|
			t.string			:name
			t.text				:tags
			t.timestamps
		end

		create_table :aristotle_offer_set_offers do |t|
			t.belongs_to	:offer_set
			t.belongs_to	:offer
			t.timestamps
		end

		create_table :aristotle_offer_set_products do |t|
			t.belongs_to	:offer_set
			t.belongs_to	:product
			t.timestamps
		end


	end
end

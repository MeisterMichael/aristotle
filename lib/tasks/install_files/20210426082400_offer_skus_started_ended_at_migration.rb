class OfferSkusStartedEndedAtMigration < ActiveRecord::Migration[5.1]
	def change

		create_table :aristotle_offer_skus do |t|
			t.belongs_to	:offer
			t.belongs_to	:sku
			t.integer			:sku_value
			t.integer			:sku_quantity
			t.datetime		:started_at
			t.datetime		:ended_at
			t.timestamps
		end

	end
end

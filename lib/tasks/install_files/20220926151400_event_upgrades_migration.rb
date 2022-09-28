class EventUpgradesMigration < ActiveRecord::Migration[5.1]
	def change

		change_table :aristotle_events do |t|
			t.belongs_to :from_product
			t.belongs_to :from_offer
		end

	end
end

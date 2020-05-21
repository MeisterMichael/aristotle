class EventSubscriptionMigration < ActiveRecord::Migration[5.1]
	def change

		change_table :aristotle_events do |t|
			t.belongs_to :subscription
		end

	end
end

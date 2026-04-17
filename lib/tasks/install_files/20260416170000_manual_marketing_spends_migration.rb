class ManualMarketingSpendsMigration < ActiveRecord::Migration[5.1]
	def change
		change_table :aristotle_marketing_spends do |t|
			t.boolean "is_manual", default: false
			t.index ["is_manual"]
		end

		change_table :aristotle_marketing_spend_sets do |t|
			t.boolean "is_manual", default: false
			t.index ["is_manual"]
		end
	end
end

class CustomerSourcesMigration < ActiveRecord::Migration[5.1]
	def change

		change_table :aristotle_customers do |t|
			t.integer "sources_version", default: 0
			t.text "sources", default: [], array: true
			t.index ["sources"], name: "index_aristotle_customers_on_sources", using: :gin
		end

	end

end

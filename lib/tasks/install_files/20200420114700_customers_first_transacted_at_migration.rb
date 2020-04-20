class CustomersFirstTransactedAtMigration < ActiveRecord::Migration[5.1]
	def change


		change_table :aristotle_customers do |t|
			t.timestamp :first_transacted_at, default: nil
		end

	end
end

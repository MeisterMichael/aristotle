class TransactionItemOfferTypeMigration < ActiveRecord::Migration[5.1]
	def change

		add_column :aristotle_transaction_items, :offer_type, :integer
		add_column :aristotle_transaction_items, :subscription_interval, :integer, default: 1

		add_index :aristotle_transaction_items, :offer_type
		add_index :aristotle_transaction_items, :subscription_interval

	end
end

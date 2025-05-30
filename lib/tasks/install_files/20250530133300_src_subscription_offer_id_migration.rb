class SrcSubscriptionOfferIdMigration < ActiveRecord::Migration[5.1]
	def change

		change_table :aristotle_subscriptions do |t|
			t.string :src_subscription_offer_id
		end

		change_table :aristotle_transaction_items do |t|
			t.string :src_subscription_offer_id
		end

		change_table :aristotle_transaction_skus do |t|
			t.string :src_subscription_offer_id
		end
	end

end

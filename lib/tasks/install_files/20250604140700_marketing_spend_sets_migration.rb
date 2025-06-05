class MarketingSpendSetsMigration < ActiveRecord::Migration[5.1]
	def change


		change_table :aristotle_marketing_spends do |t|
			t.belongs_to :marketing_spend_set, default: nil
		end

		create_table :aristotle_marketing_spend_sets do |t|
			t.string :name
			t.text :description, default: nil
			t.datetime :start_at
			t.integer :number_of_days, default: 1 # min 1, max: infinity

			t.integer "sent_count_total", default: nil
			t.integer "open_count_total", default: nil
			t.integer "open_uniq_count_total", default: nil
			t.integer "click_count_total", default: nil
			t.integer "click_uniq_count_total", default: nil
			t.integer "purchase_count_total", default: nil
			t.integer "purchase_uniq_count_total", default: nil
			t.integer "purchase_value_total", default: nil
			t.integer "spend_total", default: nil


			t.string "source", default: nil
			t.string "medium", default: nil
			t.string "content", default: nil
			t.string "term", default: nil
			t.string "campaign", default: nil
			t.string "data_src", default: nil
			t.string "src_account_id", default: nil
			t.string "src_account_name", default: nil
			t.string "src_campaign_id", default: nil
			t.integer "purpose", default: nil
			t.string "research_type", default: nil
			t.string "campaign_id", default: nil
			t.integer "email_campaign_id", default: nil

			t.timestamps
		end

	end

end

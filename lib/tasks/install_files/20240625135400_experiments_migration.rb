class ExperimentsMigration < ActiveRecord::Migration[5.1]
	def change


		change_table :aristotle_transaction_items do |t|
			t.string :src_experiment_id, default: nil
			t.string :src_trial_id, default: nil
			t.string :src_variant_id, default: nil
			t.string :experiment_name, default: nil
			t.string :variant_name, default: nil
			t.json	 :experiments_cache, default: []
		end

		change_table :aristotle_transaction_skus do |t|
			t.string :src_experiment_id, default: nil
			t.string :src_trial_id, default: nil
			t.string :src_variant_id, default: nil
			t.string :experiment_name, default: nil
			t.string :variant_name, default: nil
			t.json	 :experiments_cache, default: []
		end

		change_table :aristotle_orders do |t|
			t.string :src_experiment_id, default: nil
			t.string :src_trial_id, default: nil
			t.string :src_variant_id, default: nil
			t.string :experiment_name, default: nil
			t.string :variant_name, default: nil
			t.json	 :experiments_cache, default: []
		end

		change_table :aristotle_subscriptions do |t|
			t.string :src_experiment_id, default: nil
			t.string :src_trial_id, default: nil
			t.string :src_variant_id, default: nil
			t.string :experiment_name, default: nil
			t.string :variant_name, default: nil
			t.json	 :experiments_cache, default: []
		end
	end

end

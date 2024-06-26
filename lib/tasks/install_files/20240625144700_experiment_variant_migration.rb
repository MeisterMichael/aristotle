class ExperimentVariantMigration < ActiveRecord::Migration[5.1]
	def change


		change_table :aristotle_transaction_items do |t|
			t.belongs_to :experiment_variant
		end

		change_table :aristotle_transaction_skus do |t|
			t.belongs_to :experiment_variant
		end

		change_table :aristotle_orders do |t|
			t.belongs_to :experiment_variant
		end

		change_table :aristotle_subscriptions do |t|
			t.belongs_to :experiment_variant
		end


		
		create_table :aristotle_experiment_variants do |t|
			t.string :data_src, default: nil
			t.string :src_experiment_id, default: nil
			t.string :src_variant_id, default: nil
			t.string :experiment_name, default: nil
			t.string :variant_name, default: nil
			t.belongs_to :experiment, default: nil
			t.timestamps

			t.index [:src_variant_id, :src_experiment_id], name: 'index_aristotle_experiment_variants_on_src_variant_id'
			t.index [:experiment_name]
			t.index [:variant_name,:experiment_name], name: 'index_aristotle_experiment_variants_on_variant_name'
		end

		create_table :aristotle_experiments do |t|
			t.string :data_src, default: nil
			t.string :src_experiment_id, default: nil
			t.string :experiment_name, default: nil
			t.timestamps

			t.index [:src_experiment_id]
			t.index [:experiment_name]
		end
	end

end

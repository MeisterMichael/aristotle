class ExperimentParticipationMigration < ActiveRecord::Migration[5.1]
	def change
		create_table :aristotle_experiment_participations do |t|
			t.belongs_to :experiment
			t.belongs_to :experiment_variant, index: { name: 'index_aristotle_experiment_participations_on_experiment_variant' }
			t.belongs_to :customer
			t.datetime :joined_at
			t.string :src_participantion_id
			t.string :src_participant_id
			t.string :data_src
			t.timestamps
		end
	end

end

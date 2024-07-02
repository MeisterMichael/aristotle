module Aristotle
	class ExperimentParticipation < ApplicationRecord
		belongs_to :experiment, required: true
		belongs_to :experiment_variant, required: true
		belongs_to :customer, required: false

		# joined_at : timestamp
	end
end

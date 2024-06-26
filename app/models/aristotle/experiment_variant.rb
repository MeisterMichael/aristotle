module Aristotle
	class ExperimentVariant < ApplicationRecord
		belongs_to :experiment, required: false
	end
end

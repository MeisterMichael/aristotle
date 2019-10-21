module Aristotle
	class AppProperty < ApplicationRecord
		def self.[](key)
			self.where( key: key ).pluck(:value).first
		end

		def self.[]=(key,value)
			self.where( key: key ).first_or_initialize.update( value: value )
		end
	end
end

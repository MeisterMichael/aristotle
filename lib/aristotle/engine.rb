module Aristotle

	class << self 
		##### config vars
		#mattr_accessor :something

		#self.something = 'default'
	end

	# this function maps the vars from your app into your engine
	def self.configure( &block )
		yield self
	end


	class Engine < ::Rails::Engine
		isolate_namespace Aristotle
	end
end

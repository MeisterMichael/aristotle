module Aristotle

	mattr_accessor :internal_hosts
	mattr_accessor :order_data_sources
	self.internal_hosts = []
	self.order_data_sources = []

	# this function maps the vars from your app into your engine
	def self.configure( &block )
		yield self
	end


	class Engine < ::Rails::Engine
		isolate_namespace Aristotle

		config.autoload_paths += %W(#{config.root}/app/reports)
	end
end

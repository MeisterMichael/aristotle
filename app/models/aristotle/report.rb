require 'csv'

module Aristotle
	class Report

		def initialize( options = {} )
			@options = self.class.get_class_options().deep_merge( (options || {}).to_h.deep_symbolize_keys )

			@options[:filters] ||= {}
			self.class.filters.each do |filter|
				if filter.key? :default
					default = filter[:default]
					default = default.call() if default.respond_to? :call

					@options[:filters][filter[:name].to_sym] ||= default
				end
			end

			puts @options.to_s
		end

		def self.set_columns( columns )
			@class_columns = columns
		end
		def self.columns
			if @class_columns.respond_to? :call
				@class_columns.call()
			else
				@class_columns
			end
		end


		def self.set_filters( filters )
			@class_filters = filters
		end
		def self.filters
			if @class_filters.respond_to? :call
				@class_filters.call()
			else
				@class_filters
			end
		end

		def self.get_class_options()
			@class_options ||= {}
			@class_options
		end

		def self.set_option( name, value )
			@class_options ||= {}
			@class_options[name.to_sym] = value
		end


		def columns
			self.class.columns
		end

		def description
			@options[:description]
		end

		def filters
			self.class.filters
		end

		def filter_values
			@options[:filters]
		end

		def layout
			not( @options[:embed] == '1' )
		end

		def template
			template_name = @options[:template] || 'show'
			template_name = "#{template_name}.embed" if @options[:embed]
			template_name
		end

		def title
			@options[:title] || self.class.name.underscore.humanize.titleize
		end

		def column_labels
			columns.collect{|column| column[:label] }
		end

		def objectified_row_values
			value_rows = []
			objectified_rows.each do |row|
				if row.present?
					value_rows << []
					columns.each do |column|
						value_rows.last << row[column[:label]]
					end
				end
			end
		end

		def options
			@options
		end

		def row_values
			value_rows = []
		  rows.each do |row|
				if row.present?
					value_rows << []
					columns.each do |column|
						value_rows.last << row[column[:label]]
					end
				end
			end
		end

		def objectified_rows
			new_rows = []
			rows.each do |row|
				new_rows << {}
				if row.present?
					self.columns.each do |column|
						value = row[column[:label]]
						objectified_value = objectified_value( column, value )
						new_rows.last[column[:label]] = objectified_value
					end
				end
			end

			new_rows
		end

		def objectified_value( column, value )
			objectified_value = value
			objectified_value = Time.parse( value ) if column[:type] == 'datetime'
			objectified_value = Date.parse( value ) if column[:type] == 'date'
			objectified_value = value.to_i if column[:type] == 'integer'
			objectified_value = value.to_f if column[:type] == 'float'
			objectified_value
		end

	end
end

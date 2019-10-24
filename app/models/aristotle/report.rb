require 'csv'

module Aristotle
	class Report

		def initialize( options = {} )
			@options = options
		end

		def title
			self.class.name.underscore.humanize.titleize
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
			puts "objectified_rows"
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

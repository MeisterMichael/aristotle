class ApplicationReport < Aristotle::Report

	protected
	def query_reorder( query, order = {} )
		return query unless order.present?

		# strip order by clause
		query = query.gsub(/ORDER BY (\n|.)*$/i, '')

		query = query + <<-SQL
		ORDER BY #{order.collect{ |column, direction| "#{column} #{direction}" }.join(', ')}
		SQL

		query
	end

	def execute_query( query, args={}, options = {} )
		query_reorder( query, options[:order] ) if options[:order].present?

		# query = ActiveRecord::Base.sanitize_sql_array([query, args])
		query = ActiveRecord::Base.__send__(:sanitize_sql, [query, args])

		puts "sanitized query"
		puts query

		ActiveRecord::Base.connection.execute( query )
	end

end

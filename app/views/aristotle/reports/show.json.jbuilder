google_cart_type_map = {
	"bigint" => "number",
	"date" => "date",
	"datetime" => "datetime",
	"integer" => "number",
	"float" => "number",
	"money" => "number",
	"string" => "string",
	"time" => "timeofday",
}

json.cols @report.columns do |column|
	json.id ""
	json.label column[:label]
	json.pattern ""
	json.type google_cart_type_map[column[:type]]
end

json.rows @report.objectified_row_values do |row|
	json.c @report.columns do |column|
		value = row[column[:label]]
		value_formatted = nil

		if column[:type] == 'money'
			value_formatted = number_to_currency( value )
		elsif value.respond_to?( :strftime ) && column[:type] == 'date'
			value = "Date(#{row[column[:label]].strftime("%Y,%m,%d,%H,%M,%S")})"
			value_formatted = row[column[:label]].strftime("%m/%d/%y")
		elsif value.respond_to?( :strftime ) && column[:type] == 'datetime'
			value = "Date(#{row[column[:label]].strftime("%Y,%m,%d,%H,%M,%S")})"
			value_formatted = row[column[:label]].strftime("%m/%d/%y %H:%M:%S")
		end

		json.v value
		json.f value_formatted
	end
end

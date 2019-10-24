module Aristotle
	class ReportsController < ApplicationController

		before_action :get_report, only: [:readme, :show]

		def readme
			render layout: false
		end

		def show
			respond_to do |format|
				format.json {}
				format.html {
					render layout: false
				}
				format.csv {
					csv_results = CSV.generate(headers: true) do |csv|
						csv << @report.column_labels
						@report.objectified_row_values.each { |row| csv << row }
					end
					send_data csv_results, filename: "#{@report.title.downcase.gsub(/\s+/,'-')}-#{Date.today}.csv"
				}
			end
		end

		def get_report
			begin
				report_class = params[:id].camelize.constantize
			rescue NameError => e
			end

			if report_class.present? && report_class < Report
				options = params.require(:options).permit( filters: report_class.filters.collect{|filter| filter[:name] } ) if params[:options]
				@report = report_class.new( options )
			else
				raise ActionController::RoutingError.new('Not Found')
			end
		end

	end

end

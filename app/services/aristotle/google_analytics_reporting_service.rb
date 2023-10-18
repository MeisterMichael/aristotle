
require 'google/api_client/client_secrets'
require 'google/apis/analyticsreporting_v4'
# Google::Apis.logger.level = Logger::INFO
# OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

# HOW TO GENERATE OAUTH TOKEN
# Step 1:  Choose or Create Google App, and Enable the "Google Analytics Reporting API"
# Step 2:  Create Oauth Credentials ( of type "Other" )
# Step 3:  Set those in the ENV variables: GOOGLE_ANALYTICS_APP_CLIENT_ID and GOOGLE_ANALYTICS_APP_CLIENT_SECRET
# Step 4:  Login to account that has access to the GA account
# Step 5:  Use the URL generate by GoogleAnalyticsReportingService.oauth2_request() to generate an auth code
# Step 6:  Redeem the auth code by running GoogleAnalyticsReportingService.oauth2_redeem( code )
# Step 7:  Save the resulting oauth2 token data into ENV variables: GOOGLE_ANALYTICS_OAUTH2_TOKEN_ACCESS_TOKEN, GOOGLE_ANALYTICS_OAUTH2_TOKEN_REFRESH_TOKEN, GOOGLE_ANALYTICS_OAUTH2_TOKEN_EXPIRES_IN and GOOGLE_ANALYTICS_OAUTH2_TOKEN_TOKEN_TYPE
# Reference: https://developers.google.com/analytics/devguides/reporting/core/v4/authorization#OAuth2Authorizing

# Analytics Reporting Request Resources
# Dimensions and Metrics: https://developers.google.com/analytics/devguides/reporting/core/dimsmets
# Basics: https://developers.google.com/analytics/devguides/reporting/core/v4/basics
# API Exporer: https://developers.google.com/apis-explorer/#p/analyticsreporting/v4/analyticsreporting.reports.batchGet

module Aristotle
	class GoogleAnalyticsReportingService

		# End Points
		AUTHORIZATION_URL = 'https://accounts.google.com/o/oauth2/auth'
		TOKEN_CREDENTIAL_URL = 'https://www.googleapis.com/oauth2/v4/token'
		ANALYTICS_READONLY_END_POINT = 'https://www.googleapis.com/auth/analytics.readonly'

		# Google API Analytics Reporting Module
		Analyticsreporting = Google::Apis::AnalyticsreportingV4

		def initialize( args = {} )
			@data_src = 'GoogleAnalytics'

			@default_view_id = ENV["GOOGLE_ANALYTICS_DEFAULT_VIEW_ID"]

			client_id		= args[:app_client_id] || ENV['GOOGLE_ANALYTICS_APP_CLIENT_ID']
			client_secret	= args[:app_client_secret] || ENV['GOOGLE_ANALYTICS_APP_CLIENT_SECRET']

			if args[:oauth2_token].present?

				oauth2_token = args[:oauth2_token]

			elsif ENV['GOOGLE_ANALYTICS_OAUTH2_TOKEN_ACCESS_TOKEN'].present?

				oauth2_token = {
					access_token: ENV['GOOGLE_ANALYTICS_OAUTH2_TOKEN_ACCESS_TOKEN'],
					refresh_token: ENV['GOOGLE_ANALYTICS_OAUTH2_TOKEN_REFRESH_TOKEN'],
					expires_in: ENV['GOOGLE_ANALYTICS_OAUTH2_TOKEN_EXPIRES_IN'],
					token_type: ENV['GOOGLE_ANALYTICS_OAUTH2_TOKEN_TOKEN_TYPE'],
				}

			else

				oauth2_token = {}

			end

			authorization_args = oauth2_token.merge(
				token_credential_uri: TOKEN_CREDENTIAL_URL,
				client_id: client_id,
				client_secret: client_secret
			)

			@client = Analyticsreporting::AnalyticsReportingService.new
			@client.authorization = Signet::OAuth2::Client.new( authorization_args )
			@client.authorization.fetch_access_token!

		end

		def pull_marketing_data( args={} )
			view_id = args[:view_id] || @default_view_id

			marketing_report = extract_last_attribution_marketing_report( args.merge( view_id: view_id ) )
			marketing_report.each do |marketing_report_row|

				where_attributes = marketing_report_row[:dimensions].merge(
					data_src: @data_src,
					purpose: MarketingSpend.purposes['research'],
					research_type: 'last_attribution',
					src_account_id: view_id,
					src_account_name: view_id,
				)

				marketing_spend = MarketingSpend.where( where_attributes ).first_or_initialize
				marketing_spend.attributes			= marketing_report_row[:metrics]
				puts marketing_spend.errors.full_messages unless marketing_spend.save

			end

			# marketing_report = extract_sessions_marketing_report( args.merge( view_id: view_id ) )
			# marketing_report.each do |marketing_report_row|
			#
			# 	where_attributes = marketing_report_row[:dimensions].merge(
			# 		data_src: @data_src,
			# 		purpose: 'research',
			# 		research_type: 'sessions'
			# 	)
			#
			# 	marketing_spend = MarketingSpend.where( where_attributes ).first_or_initialize
			# 	marketing_spend.attributes			= marketing_report_row[:metrics]
			# 	marketing_spend.src_account_id		= view_id
			# 	marketing_spend.src_account_name	= view_id
			# 	marketing_spend.save
			#
			# end

			return true

		end

		def self.oauth2_request( args = {} )
			args ||= {}
			# args[:adwords_app_client_id] = ENV['GOOGLE_ADWORDS_APP_CLIENT_ID']

			"#{AUTHORIZATION_URL}?access_type=offline&client_id=#{args[:adwords_app_client_id]}&redirect_uri=urn:ietf:wg:oauth:2.0:oob&response_type=code&scope=#{ANALYTICS_READONLY_END_POINT}"
		end

		def self.oauth2_redeem( code, args = {} )
			args ||= {}
			# args[:adwords_app_client_id] = ENV['GOOGLE_ADWORDS_APP_CLIENT_ID']
			# args[:adwords_app_client_secret] = ENV['GOOGLE_ADWORDS_APP_CLIENT_SECRET']

			body = {
				code: code,
				client_id: args[:adwords_app_client_id],
				client_secret: args[:adwords_app_client_secret],
				redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
				grant_type: 'authorization_code',
				# code_verifier: ,
			}
			url = TOKEN_CREDENTIAL_URL
			headers = { content_type: 'application/x-www-form-urlencoded' }

			puts "POST #{url} => #{body}"

			response = RestClient::Request.execute( method: :post, url: url, :payload => body, headers: headers, verify_ssl: false )
			# response = RestClient::Request.new(:method => :post, :url => url, :payload => body, :headers => headers, :verify_ssl => false).execute
			# response = RestClient.post( url, body, headers )

			response.body
		end

		private

		# returns an array of marketing attributes, filtered by arguments, and
		# broken out into dimensions and metrics.
		def extract_last_attribution_marketing_report( args = {} )
			view_id		= args[:view_id]

			end_at 		= args[:end_at] || Time.now
			start_at 	= args[:start_at] || (2.week.ago + 1.day)

			start_at 	= start_at.strftime('%Y-%m-%d') unless start_at.is_a? String
			end_at 		= end_at.strftime('%Y-%m-%d') unless end_at.is_a? String

			# queries session with at least one transaction.  Which would be the last
			# one before a sale, thus giving us the last attribution.
			report_request_data = {
				"dimensions" => [
					{
						"name" => "ga:segment"
					},
					{
						"name" => "ga:date"
					},
					{
						"name" => "ga:medium"
					},
					{
						"name" => "ga:campaign"
					},
					{
						"name" => "ga:adContent"
					},
					{
						"name" => "ga:source"
					},
					{
						"name" => "ga:keyword"
					},
				],
				"viewId" => view_id,
				"metrics" => [
					{
						"expression" => "ga:uniquePurchases",
						"formattingType" => "INTEGER"
					},
					{
						"expression" => "ga:sessions",
						"formattingType" => "INTEGER"
					},
					{
						"expression" => "ga:totalValue",
						"formattingType" => "FLOAT"
					}
				],
				"segments" => [
					{
						"dynamicSegment" => {
							"sessionSegment" => {
								"segmentFilters" => [
									{
										"simpleSegment" => {
											"orFiltersForSegment" => [
												{
													"segmentFilterClauses" => [
														{
															"metricFilter" => {
																"comparisonValue" => "0",
																"operator" => "GREATER_THAN",
																"metricName" => "ga:uniquePurchases"
															}
														}
													]
												}
											]
										}
									}
								]
							},
							"name" => "Sessions	with Purchases"
						}
					}
				],
				"dateRanges" => [
					{
						"startDate" => start_at,
						"endDate" => end_at
					}
				]
			}

			report_request = build_report_request( report_request_data )

			report = get_report( report_request )

			marketing_report_rows = []

			while( report.present? && report.data.present? && report.data.rows.present? )

				report.data.rows.each do |row|


					metric_values = row.metrics.first.values
					dimension_values = row.dimensions

					dimension_values.each_with_index do |value,index|
						dimension_values[index] = nil if ['(not set)','(none)', '(not provided)'].include? value
					end

					# dimensions
					dimensions = {
						'ga:segment' 	=> dimension_values[0],
						'ga:date' 		=> dimension_values[1],
						'ga:medium' 	=> dimension_values[2],
						'ga:campaign' 	=> dimension_values[3],
						'ga:adContent'	=> dimension_values[4],
						'ga:source'		=> dimension_values[5],
						'ga:keyword'	=> dimension_values[6],
					}

					# metrics
					metrics = {
						'ga:uniquePurchases'	=> metric_values[0],
						'ga:sessions'			=> metric_values[1],
						'ga:totalValue'			=> metric_values[2],
					}

					start_at 	= Time.parse( dimensions['ga:date'] ).beginning_of_day
					end_at 		= start_at.end_of_day

					marketing_report_rows << {
						dimensions: {
							start_at:				start_at,
							end_at: 				end_at,
							source:					dimensions['ga:source'],
							medium:					dimensions['ga:medium'],
							campaign:				dimensions['ga:campaign'],
							content:				dimensions['ga:adContent'],
							term:					dimensions['ga:keyword'],
						},
						metrics: {
							purchase_count:			metrics['ga:uniquePurchases'],
							purchase_uniq_count:	metrics['ga:uniquePurchases'],
							purchase_value:			(metrics['ga:totalValue'].to_f * 100).to_i,
						},
					}

				end


				report = get_report( report_request, next_page_token: report.next_page_token )
			end

			marketing_report_rows

		end

		def extract_sessions_marketing_report( args = {} )
			view_id		= args[:view_id]

			end_at 		= args[:end_at] || Time.now
			start_at 	= args[:start_at] || (2.week.ago + 1.day)

			start_at 	= start_at.strftime('%Y-%m-%d') unless start_at.is_a? String
			end_at 		= end_at.strftime('%Y-%m-%d') unless end_at.is_a? String

			# queries session with at least one transaction.  Which would be the last
			# one before a sale, thus giving us the last attribution.
			report_request_data = {
				"dimensions" => [
					{
						"name" => "ga:date"
					},
					{
						"name" => "ga:medium"
					},
					{
						"name" => "ga:campaign"
					},
					{
						"name" => "ga:adContent"
					},
					{
						"name" => "ga:source"
					},
					{
						"name" => "ga:keyword"
					},
				],
				"viewId" => view_id,
				"metrics" => [
					{
						"expression" => "ga:sessions",
						"formattingType" => "INTEGER"
					},
				],
				"dateRanges" => [
					{
						"startDate" => start_at,
						"endDate" => end_at
					}
				]
			}

			report_request = build_report_request( report_request_data )

			report = get_report( report_request )

			marketing_report_rows = []

			while( report.present? )

				report.data.rows.each do |row|


					metric_values = row.metrics.first.values
					dimension_values = row.dimensions

					dimension_values.each_with_index do |value,index|
						dimension_values[index] = nil if ['(not set)','(none)', '(not provided)'].include? value
					end

					# dimensions
					dimensions = {
						'ga:date' 		=> dimension_values[0],
						'ga:medium' 	=> dimension_values[1],
						'ga:campaign' 	=> dimension_values[2],
						'ga:adContent'	=> dimension_values[3],
						'ga:source'		=> dimension_values[4],
						'ga:keyword'	=> dimension_values[5],
					}

					# metrics
					metrics = {
						'ga:sessions'			=> metric_values[0]
					}

					start_at 	= Time.parse( dimensions['ga:date'] ).beginning_of_day
					end_at 		= start_at.end_of_day

					marketing_report_rows << {
						dimensions: {
							start_at:			start_at,
							end_at: 			end_at,
							source:				dimensions['ga:source'],
							medium:				dimensions['ga:medium'],
							campaign:			dimensions['ga:campaign'],
							content:			dimensions['ga:adContent'],
							term:				dimensions['ga:keyword'],
						},
						metrics: {
							click_count:		metrics['ga:sessions'],
							click_uniq_count:	metrics['ga:sessions'],
						},
					}

				end


				report = get_report( report_request, next_page_token: report.next_page_token )
			end

			marketing_report_rows

		end

		def build_get_reports_request( report_requests_data )
			report_requests = []

			report_requests_data.each do |report_request_data|
				report_requests << build_analyticsreporting_object( Analyticsreporting::ReportRequest.new, report_request_data )
			end

			Analyticsreporting::GetReportsRequest.new( report_requests: report_requests )

		end

		def get_report( report_request, args = {} )
			return nil if args.has_key?(:next_page_token) && args[:next_page_token].nil?

			report_request.page_token = args[:next_page_token]
			get_report_request = Analyticsreporting::GetReportsRequest.new( report_requests: [report_request] )
			report = @client.batch_get_reports( get_report_request ).reports.first

			report
		end

		def build_analyticsreporting_object( object, cammel_case_attributes )

			cammel_case_attributes.each do |attribute, data|


				attribute_value = data

				if data.is_a? Hash

					attribute_class = attribute.sub(/^./, &:upcase)
					attribute_class = 'SegmentDefinition' if ['SessionSegment', 'UserSegment'].include?( attribute_class )

					attribute_value = "#{Analyticsreporting.name}::#{attribute_class}".constantize.new
					build_analyticsreporting_object( attribute_value, data )

				elsif data.is_a? Array

					attribute_value = []

					data.each do |array_data_element|
						child_object = "#{Analyticsreporting.name}::#{attribute.sub(/^./, &:upcase).singularize}".constantize.new
						attribute_value << build_analyticsreporting_object( child_object, array_data_element )
					end


				end

				object.try("#{attribute.underscore}=",attribute_value)
			end

			object
		end

		def build_report_request( report_request_data )
			build_analyticsreporting_object( Analyticsreporting::ReportRequest.new, report_request_data )
		end

	end
end

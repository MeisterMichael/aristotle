
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

# Documentation for the data import
# https://stackoverflow.com/questions/75434844/google-analytics-reporting-v4-with-streams-instead-of-views
# https://www.contentful.com/help/google-analytics-service-account-setup/
# https://developers.google.com/analytics/devguides/reporting/data/v1/rest/v1beta/properties/runReport



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

			@default_property_id = args[:property_id] || "289830195"
			

			@client = Google::Analytics::Data.analytics_data do |config|

				if args[:credentials].present?
					config.credentials = args[:credentials]
				else
					config.credentials = JSON.parse( ENV['GOOGLE_ANALYTICS_DATA_ACCOUNT'] )
				end

				# config.credentials = "account.json"
				# config.credentials = {
				# 	"type": "****",
				# 	"project_id": "****",
				# 	"private_key_id": "****",
				# 	"private_key": "****",
				# 	"client_email": "****",
				# 	"client_id": "****",
				# 	"auth_uri": "****",
				# 	"token_uri": "****",
				# 	"auth_provider_x509_cert_url": "****",
				# 	"client_x509_cert_url": "****",
				# 	"universe_domain": "****""
				# }

			end


		end

		def pull_marketing_data( args={} )

			property_id = args[:property_id] || @default_property_id
			
			marketing_report = extract_last_attribution_marketing_report( args.merge( property_id: property_id ) )
			marketing_report.each do |marketing_report_row|

				where_attributes = marketing_report_row[:dimensions].merge(
					data_src: @data_src,
					purpose: MarketingSpend.purposes['research'],
					research_type: 'last_attribution',
					src_account_id: property_id,
					src_account_name: property_id,
				)

				marketing_spend = MarketingSpend.where( where_attributes ).first_or_initialize
				marketing_spend.attributes			= marketing_report_row[:metrics]
				puts marketing_spend.errors.full_messages unless marketing_spend.save

			end

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
			property_id	= args[:property_id]

			end_at 		= args[:end_at] || Time.now
			start_at 	= args[:start_at] || (2.week.ago + 1.day)

			limit = 1000
			offset = 0
			max_rows = 0

			metric_fields = [
				Google::Analytics::Data::V1beta::Metric.new(name: 'ecommercePurchases'), # transactions, ecommercePurchases | "ga:uniquePurchases"),
				Google::Analytics::Data::V1beta::Metric.new(name: 'sessions'), # "ga:sessions"),
				Google::Analytics::Data::V1beta::Metric.new(name: 'totalRevenue'), # "ga:totalValue"),
			]

			dimension_fields = [
				Google::Analytics::Data::V1beta::Dimension.new(name: "date"), # date
				Google::Analytics::Data::V1beta::Dimension.new(name: "sessionMedium"), # medium | medium
				Google::Analytics::Data::V1beta::Dimension.new(name: "sessionCampaignName"), # campaignName | campaign
				Google::Analytics::Data::V1beta::Dimension.new(name: "sessionManualAdContent"), # manualAdContent | adContent
				Google::Analytics::Data::V1beta::Dimension.new(name: "sessionSource"), # source | source
				Google::Analytics::Data::V1beta::Dimension.new(name: "sessionGoogleAdsKeyword"), # googleAdsKeyword | keyword
			]


			date_ranges = [Google::Analytics::Data::V1beta::DateRange.new(start_date: start_at.to_date.to_s, end_date: end_at.to_date.to_s)]

			metric_filter = Google::Analytics::Data::V1beta::FilterExpression.new(
				filter: Google::Analytics::Data::V1beta::Filter.new(
					field_name: 'ecommercePurchases',
					numeric_filter: Google::Analytics::Data::V1beta::Filter::NumericFilter.new(
						value: Google::Analytics::Data::V1beta::NumericValue.new( int64_value: 0 ),
						operation: Google::Analytics::Data::V1beta::Filter::NumericFilter::Operation::GREATER_THAN,
					),
				),
			)

			order_dim = Google::Analytics::Data::V1beta::OrderBy::DimensionOrderBy.new(dimension_name: "ecommercePurchases")
			orderby = Google::Analytics::Data::V1beta::OrderBy.new(desc: true, dimension: order_dim)

			puts "start_date: #{start_at.to_date.to_s}, end_date: #{end_at.to_date.to_s}, limit: #{limit}, offset: #{offset}"
			request = Google::Analytics::Data::V1beta::RunReportRequest.new(
				property: "properties/#{property_id}",
				metrics: metric_fields,
				dimensions: dimension_fields,
				date_ranges: date_ranges,
				metric_filter: metric_filter,
				order_bys: [orderby],
				limit: limit,
				offset: offset,
			)
			response = @client.run_report request
			# puts JSON.pretty_generate response.to_h
			# puts "#{(response.try(:rows) || []).count} / #{response.row_count}"

			max_rows = response.row_count

			marketing_report_rows = []

			while( response.present? && response.rows.present? )
				puts "start_date: #{start_at.to_date.to_s}, end_date: #{end_at.to_date.to_s}, limit: #{limit}, offset: #{offset}, max_rows: #{max_rows}"
				
				offset = offset + response.rows.count

				response.rows.each do |row|




					metric_values = row.metric_values.collect(&:value).collect(&:to_f)
					dimension_values = row.dimension_values.collect(&:value).collect(&:to_s)

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
						'ga:uniquePurchases'	=> metric_values[0],
						'ga:sessions'			=> metric_values[1],
						'ga:totalValue'			=> metric_values[2],
					}

					# puts JSON.pretty_generate(dimensions)
					# puts JSON.pretty_generate(metrics)

					row_start_at 	= Time.parse( dimensions['ga:date'] ).beginning_of_day
					row_end_at 		= row_start_at.end_of_day

					marketing_report_rows << {
						dimensions: {
							start_at:				row_start_at,
							end_at: 				row_end_at,
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


				# puts "JSON.pretty_generate(marketing_report_rows)"
				# puts JSON.pretty_generate(marketing_report_rows)
				# die()

				request = Google::Analytics::Data::V1beta::RunReportRequest.new(
					property: "properties/#{property_id}",
					metrics: metric_fields,
					dimensions: dimension_fields,
					date_ranges: date_ranges,
					metric_filter: metric_filter,
					order_bys: [orderby],
					limit: limit,
					offset: offset,
				)
				response = @client.run_report request
				# # puts JSON.pretty_generate response.to_h
				# response = nil
			end

			# puts JSON.pretty_generate(marketing_report_rows)

			marketing_report_rows

		end

	end
end

require 'optparse'
require 'google/ads/google_ads'

# HOW TO GENERATE OAUTH TOKEN
# Step 1:	Choose or Create Google App
# Step 2:	Create or Use Oauth Credentials ( of type "Other" )
# Step 3:	Set those in the ENV variables: GOOGLE_ADWORDS_APP_CLIENT_ID and GOOGLE_ADWORDS_APP_CLIENT_SECRET
# Step 4:	Login to account that has admin access to your AdWords accounts
# Step 5:	In the top right, above your email address there will be a "Customer ID" (e.g. 555-555-5555), set that value into ENV variable: GOOGLE_ADWORDS_CLIENT_CUSTOMER_ID
# Step 6:	Select the Cog -> Account Settings.	Then select the "AdWords API Center".
# Step 7:	Complete the process for Test, then Basic access.	Save the Developer token into ENV variable: GOOGLE_ADWORDS_API_DEVELOPER_TOKEN
# Step 8:	Run ./lib/setup/setup_oauth2.rb, follow the instructions, and redeem the code.	Save the resulting oauth2 token data into EVN variables: GOOGLE_ADWORDS_OAUTH2_TOKEN_ACCESS_TOKEN, GOOGLE_ADWORDS_OAUTH2_TOKEN_REFRESH_TOKEN, GOOGLE_ADWORDS_OAUTH2_TOKEN_ISSUED_AT and GOOGLE_ADWORDS_OAUTH2_TOKEN_EXPIRES_IN
# Reference: https://developers.google.com/adwords/api/docs/guides/authentication

# General Reference Materials:
# https://github.com/googleads/google-api-ads-ruby/blob/master/adwords_api/README.md
# https://adwords.google.com/mcm/Mcm?authuser=1&__u=5141354775&__c=4126919817#c&app=mcm
# https://github.com/googleads/google-api-ads-ruby/tree/13d6fae9f292d0b808be3e7a0223cbbcc55b8381/adwords_api/examples/adwords_on_rails
# https://github.com/googleads/google-api-ads-ruby/blob/master/adwords_api/README.md
# https://developers.google.com/adwords/api/docs/appendix/reports/account-performance-report

module Aristotle
	class GoogleAdsEtl
		PAGE_SIZE = 1000

		def initialize( args = {} )
			@data_src = 'AdWords'
			@config = args[:config] || {}
			@customer_id = @config[:authentication][:client_customer_id] if @config[:authentication].present?


			# puts "GOOGLE_ADWORDS_API_DEVELOPER_TOKEN: '#{ENV['GOOGLE_ADWORDS_API_DEVELOPER_TOKEN']}'"
			# puts "GOOGLE_ADWORDS_APP_CLIENT_ID: '#{ENV['GOOGLE_ADWORDS_APP_CLIENT_ID']}'"
			# puts "GOOGLE_ADWORDS_APP_CLIENT_SECRET: '#{ENV['GOOGLE_ADWORDS_APP_CLIENT_SECRET']}'"
			# puts "GOOGLE_ADWORDS_OAUTH2_TOKEN_REFRESH_TOKEN: '#{ENV['GOOGLE_ADWORDS_OAUTH2_TOKEN_REFRESH_TOKEN']}'"

			# @client = Google::Ads::GoogleAds::GoogleAdsClient.new
			@client = Google::Ads::GoogleAds::GoogleAdsClient.new do |c|
				# config.client_id = ENV['GOOGLE_ADWORDS_APP_CLIENT_ID'] # ENV['GOOGLE_ADWORDS_APP_CLIENT_ID'] || ENV['GOOGLE_APP_CLIENT_ID']
				# config.client_secret = ENV['GOOGLE_ADWORDS_APP_CLIENT_SECRET'] # ENV['GOOGLE_ADWORDS_APP_CLIENT_SECRET'] || ENV['GOOGLE_APP_CLIENT_SECRET']
				# config.refresh_token = ENV['GOOGLE_ADWORDS_OAUTH2_TOKEN_REFRESH_TOKEN']
				# config.developer_token = ENV['GOOGLE_ADWORDS_API_DEVELOPER_TOKEN']
				# config.issued_at = ENV['GOOGLE_ADWORDS_OAUTH2_TOKEN_ISSUED_AT']
				# config.expires_in = ENV['GOOGLE_ADWORDS_OAUTH2_TOKEN_EXPIRES_IN']
				# Treat deprecation warnings as errors will cause all deprecation warnings
				# to raise instead of calling `Warning#warn`. This lets you run your tests
				# against google-ads-googleads to make sure that you are not calling any
				# deprecated code
				c.treat_deprecation_warnings_as_errors = false

				# Warn on all deprecations. Setting this to `true` will cause the library to
				# warn every time a piece of deprecated code is called. The `false` (default)
				# behaviour is to only issue a warning once for each call site in your code.
				c.warn_on_all_deprecations = false

				# The developer token is required to authenticate that you are allowed to
				# make API calls.
				c.developer_token = ENV['GOOGLE_ADWORDS_API_DEVELOPER_TOKEN']

				# Authentication tells the API that you are allowed to make changes to the
				# specific account you're trying to access.
				# The default method of authentication is to use a refresh token, client id,
				# and client secret to generate an access token.
				c.client_id = ENV['GOOGLE_ADWORDS_APP_CLIENT_ID']
				c.client_secret = ENV['GOOGLE_ADWORDS_APP_CLIENT_SECRET']
				c.refresh_token = ENV['GOOGLE_ADWORDS_OAUTH2_TOKEN_REFRESH_TOKEN']

				# You can also authenticate using a service account. If "keyfile" is
				# specified below, then service account authentication will be assumed and
				# the above authentication fields ignored. Read more about service account
				# authentication here:
				# https://developers.google.com/google-ads/api/docs/oauth/service-accounts
				# c.keyfile = 'path/to/keyfile.json'
				# c.impersonate = 'INSERT_EMAIL_ADDRESS_TO_IMPERSONATE_HERE'

				# Alternatively, you may specify your own custom authentication, which can be:
				# A `Google::Auth::Credentials` uses a the properties of its represented
				# keyfile for authenticating requests made by this client.
				# A `String` will be treated as the path to the keyfile to be used for the
				# construction of credentials for this client.
				# A `Hash` will be treated as the contents of a keyfile to be used for the
				# construction of credentials for this client.
				# A `GRPC::Core::Channel` will be used to make calls through.
				# A `GRPC::Core::ChannelCredentials` for the setting up the RPC client. The
				# channel credentials should already be composed with a
				# `GRPC::Core::CallCredentials` object.
				# A `Proc` will be used as an updater_proc for the Grpc channel. The proc
				# transforms the metadata for requests, generally, to give OAuth credentials.
				# To use one of these methods, uncomment the following line and add some code
				# to look up one of the authentication methods listed above. If set, the
				# authentication field will override the client_id, client_secret, and
				# refresh_token fields above.
				# c.authentication = INSERT_AUTHENTICATION_METHOD_HERE

				# Required for manager accounts only: Specify the login customer ID used to
				# authenticate API calls. This will be the customer ID of the authenticated
				# manager account. If you need to use different values for this field, then
				# make sure fetch a new copy of the service after each time you change the
				# value.
				# c.login_customer_id = 'INSERT_LOGIN_CUSTOMER_ID_HERE'

				# This header is only required for methods that update the resources of an
				# entity when permissioned via Linked Accounts in the Google Ads UI
				# (account_link resource in the Google Ads API). Set this value to the
				# customer ID of the data provider that updates the resources of the specified
				# customer ID. It should be set without dashes, for example: 1234567890
				# instead of 123-456-7890.
				# Read https://support.google.com/google-ads/answer/7365001 to learn more
				# about Linked Accounts.
				# c.linked_customer_id = "INSERT_LINKED_CUSTOMER_ID_HERE"

				# Logging-related fields. You may also specify a logger after instantiation
				# by using client.logger=.

				# By default, only log warnings or errors. You can change this to 'INFO' to
				# log all requests and responses from the server.
				# Valid values are 'FATAL', 'ERROR', 'WARN', 'INFO', and 'DEBUG'
				# c.log_level = 'DEBUG'

				# The location where you want the logs to be recorded. This will be passed
				# along to the logger.
				# You can provide a filename as a String, an IO object like STDOUT or STDERR,
				# or an open file.
				c.log_target = STDOUT

				# Instead of specifying logging through level and target, you can also pass a
				# logger directly (e.g. passing Rails.logger in a config/initializer). The
				# passed logger will override log_level and log_target.
				# c.logger = Logger.new(STDOUT)

				# If you need to use a HTTP proxy you can set one with this config attribute
				# c.http_proxy = "http://example.com:8080"

			end



			@ga_service = @client.service.google_ads

			responses = @client.service.google_ads.search_stream(
				customer_id: @customer_id.gsub(/\-/,''),
				query: 'SELECT campaign.id, campaign.name FROM campaign ORDER BY campaign.id',
			)

			responses.each do |response|
				response.results.each do |row|
					puts "Campaign with ID #{row.campaign.id} and name '#{row.campaign.name}' was found."
				end
			end


		end

		def pull_marketing_spends( args={} )
			rows = self.extract_marketing_account_insights( args )

			rows.each do |row|
				start_at 	= Time.parse( row['date_start'] )
				end_at 		= Time.parse( row['date_stop'] )

				where_params = { data_src: @data_src, src_account_id: row['account_id'], src_campaign_id: row['campaign_id'], start_at: start_at, end_at: end_at }

				marketing_spend = MarketingSpend.where( where_params ).first_or_initialize
				marketing_spend.source				= marketing_spend.data_src
				marketing_spend.source				= 'YouTube' if (row['campaign_name'] =~ /youtube/i).present?
				# marketing_spend.medium			= row['']
				marketing_spend.content				= row['ad_name'] || row['adset_name']
				# marketing_spend.term				= row['']
				marketing_spend.campaign			= row['campaign_name']
				marketing_spend.src_account_name	= row['account_name']
				marketing_spend.click_count			= row['clicks']
				marketing_spend.click_uniq_count	= row['unique_clicks']
				marketing_spend.purchase_count		= row['purchase.actions']
				marketing_spend.purchase_uniq_count	= row['purchase.unique_actions']
				marketing_spend.purchase_value		= (row['purchase.action_values'] * 100).to_i
				marketing_spend.spend				= (row['spend'] * 100).to_i

				puts marketing_spend.errors.full_messages unless marketing_spend.save
			end

			return true
		end

		protected

		def extract_marketing_account_insights( args={} )
			end_at 		= args[:end_at] || Time.now
			start_at 	= args[:start_at] || (2.week.ago + 1.day)

			start_at 	= start_at.strftime('%Y-%m-%d') unless start_at.is_a? String
			end_at 		= end_at.strftime('%Y-%m-%d') unless end_at.is_a? String


			# query = <<~QUERY
			# 	SELECT
			# 		ad_group.id,
			# 		ad_group.name,
			# 		campaign.id,
			# 		campaign.name,
			# 		customer.descriptive_name,
			# 		customer.id,
			# 		metrics.clicks,
			# 		metrics.cost_micros,
			# 		metrics.conversions_by_conversion_date,
			# 		metrics.conversions_value_by_conversion_date,
			# 		segments.date
			# 	FROM ad_group
			# 	WHERE segments.date >= '#{start_at}'
			# 	WHERE segments.date <= '#{end_at}'
			# QUERY
			query = <<~QUERY
SELECT
campaign.id,
campaign.name,
customer.descriptive_name,
customer.id,
metrics.clicks,
metrics.cost_micros,
metrics.conversions,
metrics.conversions_value,
segments.date
FROM campaign
WHERE segments.date BETWEEN '#{start_at}' AND '#{end_at}'
QUERY
			#
			search_options = {
				customer_id: @customer_id.gsub(/\-/,''),
				query: query.strip,
				page_size: 1000,
			}

			# puts search_options.to_json

			response = @ga_service.search( search_options )

			if response.response.results.empty?
				puts sprintf("The given query returned no entries:\n %s", query)
				return
			end

			result_rows = {}

			response.each do |row|
				campaign = row.campaign
				ad_group = row.ad_group
				metrics = row.metrics
				segments = row.segments

				date = Date.parse( row.segments.date.to_s )

				result_row = result_rows[date.to_s]
				result_row ||= {
					'date_start'							=> date.beginning_of_day.to_s,
					'date_stop'								=> date.end_of_day.to_s,
					'account_id'							=> @customer_id,
					'account_name'						=> row.customer.descriptive_name,
					'campaign_id'							=> row.campaign.id,
					'campaign_name'						=> row.campaign.name,
					# 'adset_id'								=> row.ad_group.id,
					# 'adset_name'							=> row.ad_group.name,
					# 'ad_id'										=> row.ad.id,
					# 'ad_name'									=> row.ad.name,
					'spend' 									=> (row.metrics.cost_micros.to_f / 100.0).round(2),
					'clicks' 									=> row.metrics.clicks,
					'unique_clicks'						=> row.metrics.clicks,
					'purchase.action_values'	=> row.metrics.conversions_value,
					'purchase.actions'				=> row.metrics.conversions,
					'purchase.unique_actions'	=> row.metrics.conversions,
				}
				# puts JSON.pretty_generate( result_row )
				result_rows[date.to_s] = result_row

			end

			result_rows.values

		end

	end
end

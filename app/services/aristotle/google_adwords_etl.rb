require 'adwords_api'

# HOW TO GENERATE OAUTH TOKEN
# Step 1:  Choose or Create Google App
# Step 2:  Create or Use Oauth Credentials ( of type "Other" )
# Step 3:  Set those in the ENV variables: GOOGLE_ADWORDS_APP_CLIENT_ID and GOOGLE_ADWORDS_APP_CLIENT_SECRET
# Step 4:  Login to account that has admin access to your AdWords accounts
# Step 5:  In the top right, above your email address there will be a "Customer ID" (e.g. 555-555-5555), set that value into ENV variable: GOOGLE_ADWORDS_CLIENT_CUSTOMER_ID
# Step 6:  Select the Cog -> Account Settings.  Then select the "AdWords API Center".
# Step 7:  Complete the process for Test, then Basic access.  Save the Developer token into ENV variable: GOOGLE_ADWORDS_API_DEVELOPER_TOKEN
# Step 8:  Run ./lib/setup/setup_oauth2.rb, follow the instructions, and redeem the code.  Save the resulting oauth2 token data into EVN variables: GOOGLE_ADWORDS_OAUTH2_TOKEN_ACCESS_TOKEN, GOOGLE_ADWORDS_OAUTH2_TOKEN_REFRESH_TOKEN, GOOGLE_ADWORDS_OAUTH2_TOKEN_ISSUED_AT and GOOGLE_ADWORDS_OAUTH2_TOKEN_EXPIRES_IN
# Reference: https://developers.google.com/adwords/api/docs/guides/authentication

# General Reference Materials:
# https://github.com/googleads/google-api-ads-ruby/blob/master/adwords_api/README.md
# https://adwords.google.com/mcm/Mcm?authuser=1&__u=5141354775&__c=4126919817#c&app=mcm
# https://github.com/googleads/google-api-ads-ruby/tree/13d6fae9f292d0b808be3e7a0223cbbcc55b8381/adwords_api/examples/adwords_on_rails
# https://github.com/googleads/google-api-ads-ruby/blob/master/adwords_api/README.md
# https://developers.google.com/adwords/api/docs/appendix/reports/account-performance-report

module Aristotle
	class GoogleAdwordsEtl
		API_VERSION = :v201809

		def initialize( args = {} )
			@data_src = 'AdWords'
			@config = self.class.default_api_config( args[:config] )
			@api = AdwordsApi::Api.new( @config )
			@account_id = @config[:authentication][:client_customer_id] if @config[:authentication].present?

		end

		def self.default_api_config( options = nil )

			oauth2_token = nil
			if ENV['GOOGLE_ADWORDS_OAUTH2_TOKEN_ACCESS_TOKEN'].present?
				oauth2_token = {
					access_token: ENV['GOOGLE_ADWORDS_OAUTH2_TOKEN_ACCESS_TOKEN'],
					refresh_token: ENV['GOOGLE_ADWORDS_OAUTH2_TOKEN_REFRESH_TOKEN'],
					issued_at: ENV['GOOGLE_ADWORDS_OAUTH2_TOKEN_ISSUED_AT'],
					expires_in: ENV['GOOGLE_ADWORDS_OAUTH2_TOKEN_EXPIRES_IN'],
				}
			end


			config = {
				# This is an example configuration file for the AdWords API client library.
				# Please fill in the required fields, and copy it over to your home directory.
				authentication: {
				  # Authentication method, for web applications OAuth is recommended.
				  method: 'OAuth2',

				  # Auth parameters for OAuth2 method.
				  # Set the OAuth2 client id and secret. Register your application here to
				  # obtain these values:
				  #   https://console.developers.google.com/
				  oauth2_client_id: ENV['GOOGLE_ADWORDS_APP_CLIENT_ID'] || ENV['GOOGLE_APP_CLIENT_ID'],
				  oauth2_client_secret: ENV['GOOGLE_ADWORDS_APP_CLIENT_SECRET'] || ENV['GOOGLE_APP_CLIENT_SECRET'],
				  # Optional, see: https://developers.google.com/accounts/docs/OAuth2WebServer
				  #oauth2_state: INSERT_OAUTH2_STATE_HERE,
				  #oauth2_access_type: INSERT_OAUTH2_ACCESS_TYPE_HERE,
				  #oauth2_prompt: INSERT_OAUTH2_PROMPT_HERE,
				  # Callback is set up by the application at runtime.
				  #oauth2_callback: INSERT_OAUTH2_CALLBACK_URL_HERE,
				  oauth2_token: oauth2_token,

				  # Other parameters.
				  developer_token: ENV['GOOGLE_ADWORDS_API_DEVELOPER_TOKEN'],
				  # If you access only one account you can specify it here.
				  client_customer_id: ENV['GOOGLE_ADWORDS_CLIENT_CUSTOMER_ID'],
				  user_agent: 'NHC-Analytics'
			  	},
				service: {
				  # Only production environment is available now, see: http://goo.gl/Plu3o
				  environment: 'PRODUCTION',
			  	},
				connection: {
				  # Enable to request all responses to be compressed.
				  enable_gzip: false,
				  # If your proxy connection requires authentication, make sure to include it in
				  # the URL, e.g.: http://user:password@proxy_hostname:8080
				  # proxy: INSERT_PROXY_HERE,
			  	},
				library: {
				  log_level: 'INFO', #'DEBUG',
			  	},
			}

			config = config.deep_merge( options ) if options.present?

			config
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

			start_at 	= start_at.strftime('%Y%m%d') unless start_at.is_a? String
			end_at 		= end_at.strftime('%Y%m%d') unless end_at.is_a? String

			rows = {}

			# ACCOUNT_PERFORMANCE_REPORT, CAMPAIGN_PERFORMANCE_REPORT, AD_PERFORMANCE_REPORT, ADGROUP_PERFORMANCE_REPORT
			report_type = 'CAMPAIGN_PERFORMANCE_REPORT'

			fields = %w( Date AccountDescriptiveName )
			fields = fields + %w( CampaignId CampaignName ) if %w( CAMPAIGN_PERFORMANCE_REPORT AD_PERFORMANCE_REPORT ADGROUP_PERFORMANCE_REPORT ).include?( report_type )
			fields = fields + %w( AdGroupId AdGroupName ) if %w( AD_PERFORMANCE_REPORT ADGROUP_PERFORMANCE_REPORT ).include?( report_type )
			fields = fields + %w( Id Labels ) if %w( AD_PERFORMANCE_REPORT ).include?( report_type )

			click_fields = fields + %w( Clicks Cost )
			conversion_fields = fields + %w( Conversions ConversionValue )



			click_report_definition = {
				:selector => {
					:fields => click_fields,
					:date_range => {
						:min => start_at,
						:max => end_at,
					},
				},
				:report_name => 'AdWords on Rails click report',
				:report_type => report_type,
				:download_format => 'XML',
				:date_range_type => 'CUSTOM_DATE',

			}

			conversion_report_definition = {
				:selector => {
					:fields => conversion_fields,
					:date_range => {
						:min => start_at,
						:max => end_at,
					},
					:predicates => [
						{ :field => 'ConversionTypeName', :operator => 'IN', :values => ['Website Sale'] }
					],
				},
				:report_name => 'AdWords on Rails conversion report',
				:report_type => report_type,
				:download_format => 'XML',
				:date_range_type => 'CUSTOM_DATE',

			}


			report_utils = @api.report_utils(API_VERSION)

			begin
				# Here we only expect reports that fit into memory. For large reports
				# you may want to save them to files and serve separately.

				conversion_report_data = report_utils.download_report(conversion_report_definition)
				conversion_report_doc = Nokogiri::XML(conversion_report_data)

				@api.include_zero_impressions = true
				click_report_data = report_utils.download_report(click_report_definition)
				click_report_doc = Nokogiri::XML(click_report_data)

			rescue AdwordsApi::Errors::ReportError => e
				raise e
			end


			key_columns = [ 'date_start', 'date_stop', 'account_id', 'account_name', 'campaign_id', 'campaign_name', 'adset_id', 'adset_name', 'ad_id', 'ad_name' ]

			[click_report_doc, conversion_report_doc].each do |report_doc|

				report_doc.xpath("//report/table/row").each do |row_node|
					row = {
						'date_start'	=> "#{row_node['day']} #{row_node['hourOfDay'] || '00'}:00:00 UTC",
						'date_stop'		=> "#{row_node['day']} #{row_node['hourOfDay'] || '23'}:59:59 UTC",
						'account_id'	=> @account_id,
						'account_name'	=> row_node['account'],
						'campaign_id'	=> row_node['campaignID'],
						'campaign_name'	=> row_node['campaign'],
						'adset_id'		=> row_node['adGroupID'],
						'adset_name'	=> row_node['adGroup'],
						'ad_id'			=> row_node['adID'],
						'ad_name'		=> row_node['ad'],
					}

					key = row.values.join('/')

					rows[key] ||= row
					row = rows[key]

					if row_node['clicks'].present?
						row.merge!(
							'spend' 					=> (row_node['cost'].gsub(/(^0-9\.)/,'').to_f / 1000000.0).round(2),
							'clicks' 					=> row_node['clicks'],
							'unique_clicks'				=> row_node['clicks'],
							'purchase.action_values'	=> 0.0,
							'purchase.actions'			=> 0,
							'purchase.unique_actions'	=> 0,
						)
					end

					if row_node['conversions'].present?
						row.merge!(
							'purchase.action_values'	=> row_node['totalConvValue'],
							'purchase.actions'			=> row_node['conversions'],
							'purchase.unique_actions'	=> row_node['conversions'],
						)
					end

					rows[key] = row
				end

			end

			rows.values

		end

	end
end

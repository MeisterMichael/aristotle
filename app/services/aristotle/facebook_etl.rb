module Aristotle
	class FacebookEtl

		FACEBOOK_NUMERIC_FIELDS					= %w( spend clicks unique_clicks )
		FACEBOOK_NUMERIC_COUNT_FIELDS			= %w( clicks unique_clicks )
		FACEBOOK_NUMERIC_VALUE_FIELDS			= %w( spend )

		FACEBOOK_ACTION_NUMERIC_FIELDS			= %w( actions unique_actions action_values )
		FACEBOOK_ACTION_NUMERIC_COUNT_FIELDS	= %w( actions unique_actions )
		FACEBOOK_ACTION_NUMERIC_VALUE_FIELDS	= %w( action_values )

		FACEBOOK_LEVEL_FIELDS					= %w( account_id account_name campaign_id campaign_name adset_id adset_name ad_id ad_name )

		FACEBOOK_ACTION_TYPES					= %w( offsite_conversion.fb_pixel_purchase )

		SRC_ACCOUNT_NAME_AMALGAMATION			= {}

		def initialize( args = {} )
			@data_src = 'Facebook'
			@marketing_accounts = args[:marketing_accounts] || (ENV['FACEBOOK_MARKETING_ACCOUNTS'] || '').split(',')

		end

		def pull_marketing_spends( args={} )
			rows = self.extract_marketing_account_insights( args )
			# puts JSON.pretty_generate rows
			# die()

			rows.each do |row|
				start_at = Time.parse( "#{row['date_start']} UTC" ).beginning_of_day
				end_at = Time.parse( "#{row['date_stop']} UTC" ).end_of_day

				src_account_name = row['account_name']
				src_account_id   = row['account_id'] || src_account_name

				where_params = { data_src: @data_src, src_account_id: src_account_id, src_campaign_id: row['campaign_id'], start_at: start_at, end_at: end_at }

				marketing_spend = MarketingSpend.where( where_params ).first_or_initialize
				marketing_spend.source				= marketing_spend.data_src
				# marketing_spend.medium			= row['']
				marketing_spend.content				= row['ad_name'] || row['adset_name']
				# marketing_spend.term				= row['']
				marketing_spend.campaign			= row['campaign_name']
				marketing_spend.src_account_name	= src_account_name
				marketing_spend.click_count			= row['clicks']
				marketing_spend.click_uniq_count	= row['unique_clicks']
				marketing_spend.purchase_count		= row['purchase.actions']
				marketing_spend.purchase_uniq_count	= row['purchase.unique_actions']
				marketing_spend.purchase_value		= (row['purchase.action_values'] * 100).to_i
				marketing_spend.spend				= (row['spend'] * 100).to_i

				begin
					puts marketing_spend.errors.full_messages unless marketing_spend.save
				rescue Exception => e
					puts JSON.pretty_generate row
					puts JSON.pretty_generate marketing_spend.attributes
					puts e
				end
			end
		end

		protected

		def extract_marketing_account_insights( args={} )
			end_at 		= args[:end_at] || Time.now
			start_at 	= args[:start_at] || (30.days.ago + 1.day)

			start_at 	= start_at.strftime('%Y-%m-%d') unless start_at.is_a? String
			end_at 		= end_at.strftime('%Y-%m-%d') unless end_at.is_a? String

			ad_account_ids 	= args[:marketing_accounts] || @marketing_accounts
			level			= args[:level] || 'campaign'

			rows = []

			fields = FACEBOOK_NUMERIC_FIELDS + FACEBOOK_ACTION_NUMERIC_FIELDS + %w( objective website_purchase_roas account_id account_name )
			fields = fields + %w( campaign_id campaign_name ) if %w(ad adset campaign).include? level
			fields = fields + %w( adset_id, adset_name ) if %w(ad, adset).include? level
			fields = fields + %w( ad_id, ad_name ) if %w(ad).include? level


			ad_account_ids.each do |ad_account_id|
				puts "ad_account_id #{ad_account_id} (#{start_at}...#{end_at})"
				ad_account = FacebookAds::AdAccount.get(ad_account_id,'name')
				ad_account_name = SRC_ACCOUNT_NAME_AMALGAMATION[ad_account.name] || ad_account.name
				puts "  -> #{ad_account_name}"


				insights = ad_account.insights( fields: fields, time_range: { 'since' => start_at, 'until' => end_at }, level: level, time_increment: 1 )

				# insights.each do |insight_row|
				# 	puts JSON.pretty_generate insight_row
				# end

				insights.each do |insight_row|

					# puts JSON.pretty_generate insight_row
					# die()

					row = { 'date_start' => insight_row['date_start'], 'date_stop' => insight_row['date_stop'] } #{ 'account_id' => ad_account_id, 'account_name' => ad_account.name }

					row['action_types'] = (insight_row['actions'] || []).collect{|ar| ar['action_type'] }

					FACEBOOK_LEVEL_FIELDS.each do |field|
						row[field] = insight_row[field] if insight_row[field].present?
					end

					FACEBOOK_NUMERIC_FIELDS.each do |field|
						row[field] = insight_row[field].to_f
					end

					FACEBOOK_ACTION_NUMERIC_FIELDS.each do |action_field|
						row['purchase.'+action_field] = 0.0
						row['link_click.'+action_field] = 0.0
						row['landing_page_view.'+action_field] = 0.0

						(insight_row[action_field] || []).each do |action_field_row|
							row['purchase.'+action_field] = action_field_row['value'].to_f if ['offsite_conversion.fb_pixel_purchase'].include? action_field_row['action_type']
							row['link_click.'+action_field] = action_field_row['value'].to_f if ['link_click'].include? action_field_row['action_type']
							row['landing_page_view.'+action_field] = action_field_row['value'].to_f if ['landing_page_view'].include? action_field_row['action_type']
						end
					end

					row['account_name']	= ad_account_name
					row['account_id']	= ad_account_id

					rows << row

				end


			end


			rows

		end

	end
end

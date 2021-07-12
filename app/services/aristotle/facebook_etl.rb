module Aristotle
	class FacebookEtl

		FAILURE_COOLDOWN_SECONDS = 120.000
		MAX_FAILURE_ATTEMPTS = 5

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
			@insights_window = args[:insights_window] || 5.days
			@cooldown_seconds = 0.000
			@cooldown_seconds = args[:api_rest_seconds] if args[:api_rest_seconds].present?
		end

		def pull_marketing_spends( args={} )
			rows = self.extract_marketing_account_insights( args )
			# puts JSON.pretty_generate rows
			# die() if rows.present?

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
			rows = nil
			if args[:start_at].present?
				end_at 		= args[:end_at] || Time.now
				start_at 	= args[:start_at] || (end_at - @insights_window)
				rows = extract_marketing_account_insights_window( start_at, end_at )
			else
				initial_end_at = Time.now

				rows = []
				(0..3).each do |index|
					start_at = initial_end_at - ((index + 1) * @insights_window)
					end_at = initial_end_at - ( index * @insights_window )
					# puts "interval index #{index}: #{start_at}, #{end_at}"

					rows = extract_marketing_account_insights_window( start_at, end_at ) + rows
				end
			end

			rows
		end

		def extract_marketing_account_insights_window( start_at, end_at, args={} )

			start_at 	= start_at.strftime('%Y-%m-%d') unless start_at.is_a? String
			end_at 		= end_at.strftime('%Y-%m-%d') unless end_at.is_a? String

			ad_account_ids 	= args[:marketing_accounts] || @marketing_accounts
			level			= args[:level] || 'campaign'

			rows = []

			fields = FACEBOOK_NUMERIC_FIELDS + FACEBOOK_ACTION_NUMERIC_FIELDS + %w( account_id account_name ) # objective website_purchase_roas
			fields = fields + %w( campaign_id campaign_name ) if %w(ad adset campaign).include? level
			fields = fields + %w( adset_id, adset_name ) if %w(ad, adset).include? level
			fields = fields + %w( ad_id, ad_name ) if %w(ad).include? level


			ad_account_ids.each do |ad_account_id|
				puts "ad_account_id #{ad_account_id} (#{start_at}...#{end_at})"
				ad_account = FacebookAds::AdAccount.get(ad_account_id,'name')
				ad_account_name = SRC_ACCOUNT_NAME_AMALGAMATION[ad_account.name] || ad_account.name
				puts "  -> #{ad_account_name}"

				insight_options = {
					# action_attribution_windows: %w(7d_click 1d_view),
					# use_unified_attribution_setting: true,
					fields: fields,
					time_range: { 'since' => start_at, 'until' => end_at },
					level: level,
					time_increment: '1'
				}
				puts "    ( #{insight_options.to_json} )"

				attempt = 0
				while( true ) do
					attempt = attempt + 1
					puts "        attempt #{attempt}"
					account_rows = []

					begin
						#FacebookAds::ServerError: Please reduce the amount of data you're asking for, then retry your request
						insights = ad_account.insights( insight_options )

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

							account_rows << row

						end

						if @cooldown_seconds.present? && @cooldown_seconds.to_i > 0
							sleep @cooldown_seconds
						end

						puts "        attempt #{attempt} success"
						break
					rescue Exception => e
						raise e if attempt >= MAX_FAILURE_ATTEMPTS
						puts "        attempt #{attempt} failure occurred while querying insights (#{e.message})... cooling down #{FAILURE_COOLDOWN_SECONDS}"
						sleep FAILURE_COOLDOWN_SECONDS
					end
				end

				rows = rows + account_rows

				if @cooldown_seconds.present? && @cooldown_seconds.to_i > 0
					sleep @cooldown_seconds
				end
			end


			rows

		end

	end
end

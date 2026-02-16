require 'rest-client'
require 'json'

module Aristotle
	class TikTokAdsEtl

		TIKTOK_ADS_BASE_URL = 'https://business-api.tiktok.com/open_api/v1.3'
		MAX_PAGE_SIZE = 1000
		MAX_RETRIES = 5
		RETRY_DELAY = 5

		def initialize(args = {})
			@data_src = 'TikTok'
			@app_id = args[:app_id] || ENV['TIKTOK_ADS_APP_ID']
			@app_secret = args[:app_secret] || ENV['TIKTOK_ADS_APP_SECRET']
			@access_token = args[:access_token] || ENV['TIKTOK_ADS_ACCESS_TOKEN']
			@advertiser_ids = args[:advertiser_ids] || (ENV['TIKTOK_ADS_ADVERTISER_IDS'] || '').split(',').map(&:strip).reject(&:blank?)

			puts "TikTokAdsEtl.new > data_src: #{@data_src}, advertiser_ids: #{@advertiser_ids.join(', ')}"
		end

		def pull_marketing_spends(args = {})
			end_at = args[:end_at] || Time.now
			start_at = args[:start_at] || 2.weeks.ago

			@advertiser_ids.each do |advertiser_id|
				puts "\n\nTikTok Ads: Processing advertiser #{advertiser_id}"

				begin
					rows = extract_marketing_account_insights(
						advertiser_id: advertiser_id,
						start_at: start_at,
						end_at: end_at,
					)

					puts "  -> #{rows.count} rows"

					rows.each do |row|
						day_start = Time.parse("#{row['stat_time_day']}").beginning_of_day
						day_end = day_start.end_of_day

						where_params = {
							data_src: @data_src,
							src_account_id: advertiser_id,
							src_campaign_id: row['campaign_id'],
							start_at: day_start,
							end_at: day_end,
						}

						marketing_spend = MarketingSpend.where(where_params).first_or_initialize
						marketing_spend.source = 'TikTok'
						marketing_spend.campaign = row['campaign_name']
						marketing_spend.src_account_name = advertiser_id
						marketing_spend.click_count = row['clicks'].to_i
						marketing_spend.purchase_count = row['conversion'].to_i
						marketing_spend.purchase_value = (row['complete_payment_value'].to_f * 100).to_i
						marketing_spend.spend = (row['spend'].to_f * 100).to_i

						unless marketing_spend.save
							puts "    -> Error saving: #{marketing_spend.errors.full_messages}"
						end
					end

				rescue Exception => e
					puts "  -> Error for advertiser #{advertiser_id}: #{e.message}"
					raise e
				end
			end
		end

		protected

		def extract_marketing_account_insights(advertiser_id:, start_at:, end_at:)
			start_date = start_at.strftime('%Y-%m-%d')
			end_date = end_at.strftime('%Y-%m-%d')

			all_rows = []
			page = 1

			loop do
				params = {
					advertiser_id: advertiser_id,
					report_type: 'BASIC',
					data_level: 'AUCTION_CAMPAIGN',
					dimensions: '["campaign_id", "stat_time_day"]',
					metrics: '["spend", "impressions", "clicks", "conversion", "complete_payment"]',
					start_date: start_date,
					end_date: end_date,
					page: page,
					page_size: MAX_PAGE_SIZE,
				}

				response = tiktok_ads_get('/report/integrated/get/', params)

				rows = response.dig(:data, :list) || []

				rows.each do |row|
					dimensions = row[:dimensions] || {}
					metrics = row[:metrics] || {}

					all_rows << {
						'campaign_id' => dimensions[:campaign_id],
						'campaign_name' => dimensions[:campaign_name],
						'stat_time_day' => dimensions[:stat_time_day],
						'spend' => metrics[:spend],
						'impressions' => metrics[:impressions],
						'clicks' => metrics[:clicks],
						'conversion' => metrics[:conversion],
						'complete_payment_value' => metrics[:complete_payment],
					}
				end

				page_info = response.dig(:data, :page_info) || {}
				total_pages = page_info[:total_page] || 1
				break if page >= total_pages || rows.empty?

				page += 1
			end

			all_rows
		end

		private

		def tiktok_ads_get(path, params = {})
			url = "#{TIKTOK_ADS_BASE_URL}#{path}"

			retries = 0
			begin
				response = RestClient::Request.execute(
					method: :get,
					url: url,
					headers: {
						params: params,
						'Access-Token' => @access_token,
						content_type: :json,
						accept: :json,
					},
					open_timeout: 10,
					timeout: 60,
				)

				parsed = JSON.parse(response.body, symbolize_names: true)

				if parsed[:code] != 0
					error_msg = "TikTok Ads API Error: code=#{parsed[:code]} message=#{parsed[:message]}"
					puts error_msg
					raise StandardError.new(error_msg)
				end

				parsed

			rescue RestClient::TooManyRequests => e
				retries += 1
				if retries <= MAX_RETRIES
					delay = RETRY_DELAY * (2 ** (retries - 1))
					puts "TikTok Ads API rate limited. Retrying in #{delay}s (attempt #{retries}/#{MAX_RETRIES})"
					sleep delay
					retry
				end
				raise e

			rescue RestClient::Exception => e
				retries += 1
				if retries <= MAX_RETRIES && e.http_code.to_i >= 500
					delay = RETRY_DELAY * (2 ** (retries - 1))
					puts "TikTok Ads API server error (#{e.http_code}). Retrying in #{delay}s (attempt #{retries}/#{MAX_RETRIES})"
					sleep delay
					retry
				end
				raise e
			end
		end

	end
end

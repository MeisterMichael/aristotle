require 'rest-client'
require 'openssl'
require 'json'

module Aristotle
	module TikTokShopClient

		TIKTOK_SHOP_BASE_URL = 'https://open-api.tiktokglobalshop.com'
		TIKTOK_SHOP_API_VERSION = '202309'

		MAX_RETRIES = 5
		RETRY_DELAY = 5

		def tiktok_shop_app_key
			ENV['TIKTOK_SHOP_APP_KEY']
		end

		def tiktok_shop_app_secret
			ENV['TIKTOK_SHOP_APP_SECRET']
		end

		def tiktok_shop_access_token
			ENV['TIKTOK_SHOP_ACCESS_TOKEN']
		end

		def tiktok_shop_shop_id
			ENV['TIKTOK_SHOP_SHOP_ID']
		end

		def tiktok_shop_configured?
			tiktok_shop_app_key.present? &&
				tiktok_shop_app_secret.present? &&
				tiktok_shop_access_token.present? &&
				tiktok_shop_shop_id.present?
		end

		# Generate HMAC-SHA256 signature per TikTok Shop API requirements
		# 1. Sort query params alphabetically (excluding sign, access_token)
		# 2. Concatenate as {key}{value} pairs
		# 3. Wrap with app_secret: APP_SECRET + path + params_string + body + APP_SECRET
		# 4. HMAC-SHA256 -> uppercase hex
		def tiktok_shop_sign(path, params = {}, body = '')
			# Filter out sign and access_token from signing
			signing_params = params.reject { |k, _| %w[sign access_token].include?(k.to_s) }

			# Sort alphabetically and concatenate key-value pairs
			params_string = signing_params.sort_by { |k, _| k.to_s }.map { |k, v| "#{k}#{v}" }.join

			# Build the signing base string
			base_string = "#{tiktok_shop_app_secret}#{path}#{params_string}#{body}#{tiktok_shop_app_secret}"

			# HMAC-SHA256 and uppercase hex
			OpenSSL::HMAC.hexdigest('sha256', tiktok_shop_app_secret, base_string).upcase
		end

		def tiktok_shop_get(path, params = {})
			tiktok_shop_request(:get, path, params)
		end

		def tiktok_shop_post(path, body = {}, params = {})
			tiktok_shop_request(:post, path, params, body)
		end

		private

		def tiktok_shop_request(method, path, params = {}, body = nil)
			# Add required query parameters
			query_params = {
				'app_key' => tiktok_shop_app_key,
				'timestamp' => Time.now.to_i.to_s,
				'shop_id' => tiktok_shop_shop_id,
				'version' => TIKTOK_SHOP_API_VERSION,
			}.merge(params.stringify_keys)

			body_string = body.present? ? body.to_json : ''

			# Generate signature
			query_params['sign'] = tiktok_shop_sign(path, query_params, body_string)
			query_params['access_token'] = tiktok_shop_access_token

			url = "#{TIKTOK_SHOP_BASE_URL}#{path}"

			retries = 0
			begin
				response = if method == :get
					RestClient::Request.execute(
						method: :get,
						url: url,
						headers: { params: query_params, content_type: :json, accept: :json },
						open_timeout: 10,
						timeout: 60,
					)
				else
					RestClient::Request.execute(
						method: :post,
						url: url,
						payload: body_string,
						headers: { params: query_params, content_type: :json, accept: :json },
						open_timeout: 10,
						timeout: 60,
					)
				end

				parsed = JSON.parse(response.body, symbolize_names: true)

				# Check for TikTok API errors
				if parsed[:code] != 0
					error_msg = "TikTok Shop API Error: code=#{parsed[:code]} message=#{parsed[:message]}"
					puts error_msg
					raise StandardError.new(error_msg)
				end

				parsed

			rescue RestClient::TooManyRequests => e
				retries += 1
				if retries <= MAX_RETRIES
					delay = RETRY_DELAY * (2 ** (retries - 1))
					puts "TikTok Shop API rate limited. Retrying in #{delay}s (attempt #{retries}/#{MAX_RETRIES})"
					sleep delay
					retry
				end
				raise e

			rescue RestClient::Exception => e
				retries += 1
				if retries <= MAX_RETRIES && e.http_code.to_i >= 500
					delay = RETRY_DELAY * (2 ** (retries - 1))
					puts "TikTok Shop API server error (#{e.http_code}). Retrying in #{delay}s (attempt #{retries}/#{MAX_RETRIES})"
					sleep delay
					retry
				end
				raise e
			end
		end

	end
end

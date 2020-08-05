module Aristotle
	class BunyanEtl

		def initialize( args = {} )
			@options = args
			@options[:allow_updates] = true unless @options.key? :allow_updates
			@data_src = args[:data_src] || 'swell'
			@bazaar_data_sources = args[:bazaar_data_sources] || ['ClickBank', 'Wholesale', 'Website']
			@connection_options = args[:connection]
			# @connection_options ||= ENV['DEFAULT_SWELL_ECOM_ETL_DATABASE_URL']
			@connection_options ||= {
				adapter: 'postgresql',
				encoding: 'unicode',
				database: 'nhc_trial_store',
				password: ENV['DEV_DATABASE_PASSWORD'],
				port: ( ENV["DEV_DATABASE_PORT"] || '5432' ),
				host: ( ENV["DEV_DATABASE_HOST"] || 'localhost' ),
				username: ( ENV["DEV_DATABASE_USERNAME"] || 'postgres' ),
			}

			@internal_hosts = args[:internal_hosts] || Aristotle.internal_hosts

			@bazaar_etl = args[:bazaar_etl] || Aristotle::BazaarEtl.new( data_src: @data_src, connection: @connection_options )
		end

		def connection
			# @connection ||= ActiveRecord::Base.establish_connection(@connection_options).connection
			if @connection_options.is_a? Hash
				@connection ||= PG.connect( dbname: @connection_options[:database], password: @connection_options[:password], port: @connection_options[:port], host: @connection_options[:host], user: @connection_options[:username] )
			elsif @connection_options.is_a? String
				@connection ||= PG.connect( @connection_options )
			end
		end

		def data_src
			@data_src
		end

		def exec_query( query, args = {} )
			query = ActiveRecord::Base.__send__(:sanitize_sql, [query, args])
			connection.exec query
		end

		def process_src_event!( src_event, src_client )
			events = process_src_event( src_event, src_client )
			puts " -> saving"
			events.collect(&:save!)
			puts " -> saving done"
			events
		end

		def process_src_event( src_event, src_client )
			src_event_id = src_event.delete(:id)

			src_event[:target_obj] ||= @bazaar_etl.extract_item( src_event[:target_obj_type], src_event[:target_obj_id] )

			puts "process_src_event	#{src_event[:created_at]}	#{src_event[:name]}"#	#{src_event[:target_obj_type]}	#{src_event[:target_obj_id]}	#{src_event[:target_obj].present?}"

			event = Event.where( data_src: @data_src, src_event_id: src_event_id, name: src_event[:name] ).first if @options[:allow_updates]
			puts " -> update" if event.present?
			event ||= Event.new
			event.data_src = @data_src
			event.src_event_id = src_event_id

			if src_client
				src_client.each do |attr,val|
					attr = "client_#{attr}"
					event[attr] = val if event.respond_to? attr
				end
			end

			src_event.each do |attr,val|
				if event.respond_to? "event_#{attr}"
					event["event_#{attr}"] = val
				elsif event.respond_to? "src_#{attr}"
					event["src_#{attr}"] = val
				elsif event.respond_to? attr
					event[attr] = val
				end
			end

			if event.referrer_url.present? && event.referrer_host.blank?
				begin
					uri = URI( event.referrer_url )
					event.referrer_host ||= uri.host
					event.referrer_path ||= uri.path
					event.referrer_params ||= uri.query
				rescue Exception => e
				end
			end

			event.referrer_host_external = true if event.name == 'pageview' && event.referrer_host.present? && not( @internal_hosts.include?( event.referrer_host.downcase ) )


			# event_attributes['channel_partner']
			# event_attributes['coupon']
			event.customer = Aristotle::Customer.where( data_src: @bazaar_data_sources, src_customer_id: event.src_user_id.to_s ).first if event.src_user_id.present?
			event.customer ||= Aristotle::Customer.where( data_src: @bazaar_data_sources, src_customer_id: event.client_user_id.to_s ).first if event.client_user_id.present?
			# event_attributes['email_campaign']
			# event_attributes['location']
			# event_attributes['offer']
			# event_attributes['wholesale_client']




			if ( target_obj = src_event[:target_obj] ).present?

				case event.src_target_obj_type
				when 'Bazaar::Cart'
				when 'Bazaar::Offer'
					event.offer = Offer.where( data_src: @bazaar_data_sources, src_offer_id: "Bazaar::Offer\##{event.src_target_obj_id}" ).first
				when 'Bazaar::Order'
					event.order = Order.where( data_src: @bazaar_data_sources, src_order_id: event.src_target_obj_id ).first
				when 'Bazaar::Product'
					event.product ||= Product.where( data_src: @bazaar_data_sources, src_product_id: "Bazaar::Product\##{event.src_target_obj_id}" ).first
				when 'Bazaar::Subscription'
					event.subscription		||= Subscription.where( data_src: @bazaar_data_sources, src_subscription_id: event.src_target_obj_id ).first
					event.offer						||= event.subscription.try(:offer)
					event.offer						||= Offer.where( data_src: @bazaar_data_sources, src_offer_id: "Bazaar::Offer\##{target_obj[:offer_id]}" ).first if target_obj[:offer]
				when 'Bazaar::SubscriptionPlan'
					event.offer 	||= Offer.where( data_src: @bazaar_data_sources, src_offer_id: "Bazaar::Offer\##{target_obj[:offer_id]}" ).first if target_obj[:offer]
				when 'Bazaar::UpsellOffer'
					event.offer 	||= Offer.where( data_src: @bazaar_data_sources, src_offer_id: "Bazaar::Offer\##{target_obj[:offer_id]}" ).first if target_obj[:offer]
				end

			end

			event.product						||= event.offer.try(:product)

			event.channel_partner		||= event.subscription.try(:channel_partner)
			event.customer					||= event.subscription.try(:customer)
			event.location					||= event.subscription.try(:location)
			event.wholesale_client	||= event.subscription.try(:wholesale_client)

			event.channel_partner		||= event.order.try(:channel_partner)
			event.customer					||= event.order.try(:customer)
			event.location					||= event.order.try(:location)
			event.wholesale_client	||= event.order.try(:wholesale_client)

			events = []
			events << event

			case event.src_target_obj_type
			when 'Bazaar::Order'
				src_event[:target_obj][:order_offers].each do |src_order_offer|
					events = events + process_src_event( src_event.merge( id: src_event_id, name: "#{src_event[:name]}::offer", target_obj_id: src_order_offer[:offer_id], target_obj_type: 'Bazaar::Offer', target_obj: nil ), src_client )
				end
			when 'Bazaar::Cart'
				src_event[:target_obj][:cart_offers].each do |src_cart_offer|
					events = events + process_src_event( src_event.merge( id: src_event_id, name: "#{src_event[:name]}::offer", target_obj_id: src_cart_offer[:offer_id], target_obj_type: 'Bazaar::Offer', target_obj: nil ), src_client )
				end
			end

			events.each do |an_event|
				event.offer							||= event.offer
				event.product						||= event.product
				event.channel_partner		||= event.channel_partner
				event.customer					||= event.customer
				event.location					||= event.location
				event.wholesale_client	||= event.wholesale_client
			end

			events
		end



		def pull_and_process_events( args = {} )
			limit = 500
			offset = 0

			last_event_id = args[:last_event_id]
			last_event_id ||= Event.where( data_src: @data_src ).maximum('src_event_id::bigint')
			last_event_id ||= 0

			max_created_at = args[:max_created_at] || 1.day.ago
			min_created_at = args[:min_created_at] || Time.at(0)

			excluded_event_names = args[:excluded_event_names] || ['pageview', '404', 'get-client']

			event_query_filters = ""
			event_query_filters = event_query_filters + "AND bunyan_events.name ilike '%#{args[:ilike_name]}%'" if args[:ilike_name].present?


			client_query = <<-SQL
SELECT bunyan_clients.*
FROM bunyan_clients
WHERE bunyan_clients.id IN (:client_ids)
SQL

			event_query = <<-SQL
SELECT bunyan_events.*
FROM bunyan_events
WHERE bunyan_events.id > :last_event_id
AND bunyan_events.created_at BETWEEN :min_created_at AND :max_created_at
AND bunyan_events.name NOT IN (:excluded_event_names)
#{event_query_filters}
ORDER BY bunyan_events.id ASC
LIMIT #{limit}
SQL

			page_i = 1
			while( true ) do
				puts "Page #{page_i} (last_event_id: #{last_event_id}) - Loading"
				event_rows = exec_query( event_query, last_event_id: last_event_id, max_created_at: max_created_at, min_created_at: min_created_at, excluded_event_names: excluded_event_names )
				puts "Page #{page_i} - Loaded"

				client_row_cache = {}

				client_ids = event_rows.collect{|src_event| src_event['client_id'] }.uniq.select(&:present?)
				if client_ids.present?
					client_rows = exec_query( client_query, client_ids: client_ids )
					client_rows.each do |client_row|
						client_row.deep_symbolize_keys!
						client_row_cache[client_row[:id]] = client_row
					end
				end


				event_rows.each do |src_event|
					src_event.deep_symbolize_keys!
					src_event_id = src_event[:id]

					client_row = client_row_cache[src_event[:client_id]] if src_event[:client_id].present?


					events = process_src_event!( src_event, client_row )
					event = events.first

					if event.src_client_id.present?
						puts " -> updating client events"
						previous_client_events = Event.none
						previous_client_events = Event.where( data_src: @data_src, src_client_id: event.src_client_id, event_created_at: Time.at(0)..event.created_at ) if event.src_client_id.present?
						previous_client_events.where( customer: nil ).update_all( customer_id: event.customer.id ) if event.customer.present?
						# previous_client_events.where( order: nil ).update_all( order_id: event.order.id ) if event.order.present?
						previous_client_events.where( channel_partner: nil ).update_all( channel_partner_id: event.channel_partner.id ) if event.channel_partner.present?
						# previous_client_events.where( location: nil ).update_all( location_id: event.location.id ) if event.location.present?
						# previous_client_events.where( wholesale_client: nil ).update_all( wholesale_client_id: event.wholesale_client.id ) if event.wholesale_client.present?
						puts " -> updating client events done"
					end

					last_event_id = src_event_id
				end

				puts "Page #{page_i} - Done"

				break if event_rows.count < limit

				offset += event_rows.count

				page_i = page_i + 1

			end

		end

	end
end

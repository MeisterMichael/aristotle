module Aristotle
	class BunyanEtl

		def initialize( args = {} )
			@data_src = args[:data_src] || 'swell'
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

		def pull_and_process_events( args = {} )
			last_event_id = args[:last_event_id] || Event.where( data_src: @data_src ).order('src_event_id::float ASC').last.try(:src_event_id) || 0
			max_created_at = 1.hour.ago

			client_query = <<-SQL
SELECT bunyan_clients.*
FROM bunyan_clients
WHERE bunyan_clients.id = :client_id
SQL

			event_query = <<-SQL
SELECT bunyan_events.*
FROM bunyan_events
WHERE bunyan_events.id > :last_event_id
AND bunyan_events.created_at < :max_created_at
ORDER BY bunyan_events.id ASC
LIMIT 500
SQL

			while( ( event_rows = exec_query( event_query, last_event_id: last_event_id, max_created_at: max_created_at ) ).present? ) do
				client_row_cache = {}
				event_rows.each do |event_row|
					src_event_id = event_row.delete('id')

					client_row = client_row_cache[event_row['client_id']]
					client_row ||= exec_query( client_query, client_id: event_row['client_id'] ).first
					client_row_cache[event_row['client_id']] = client_row


					event = Event.new
					event.data_src = @data_src
					event.src_event_id = src_event_id

					if client_row
						client_row.each do |attr,val|
							attr = "client_#{attr}"
							event[attr] = val if event.respond_to? attr
						end
					end

					event_row.each do |attr,val|
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
					event.customer = Aristotle::Customer.where( data_src: @data_src, src_customer_id: event.src_user_id.to_s ).first if event.src_user_id.present?
					event.customer ||= Aristotle::Customer.where( data_src: @data_src, src_customer_id: event.client_user_id.to_s ).first if event.client_user_id.present?
					# event_attributes['email_campaign']
					# event_attributes['location']
					# event_attributes['offer']
					event.order = Order.where( data_src: @data_src, src_order_id: event.src_target_obj_id ).first if event.src_target_obj_type == 'Bazaar::Order'
					# event_attributes['product'] = Product.where( data_src: @data_src, src_product_id: event_row['src_target_obj_id'] ).first if event_row['src_target_obj_type'] == 'Bazaar::Product'
					# event_attributes['wholesale_client']

					event.channel_partner		||= event.order.try(:channel_partner)
					event.customer					||= event.order.try(:customer)
					event.location					||= event.order.try(:location)
					event.wholesale_client	||= event.order.try(:wholesale_client)

					last_event_id = src_event_id
					event.save!

					previous_client_events = Event.none
					previous_client_events = Event.where( data_src: @data_src, src_client_id: event.src_client_id, event_created_at: Time.at(0)..event.created_at ) if event.src_client_id.present?
					previous_client_events.where( customer: nil ).update_all( customer_id: event.customer.id ) if event.customer.present?
					previous_client_events.where( order: nil ).update_all( order_id: event.order.id ) if event.order.present?
					previous_client_events.where( channel_partner: nil ).update_all( channel_partner_id: event.channel_partner.id ) if event.channel_partner.present?
					previous_client_events.where( location: nil ).update_all( location_id: event.location.id ) if event.location.present?
					previous_client_events.where( wholesale_client: nil ).update_all( wholesale_client_id: event.wholesale_client.id ) if event.wholesale_client.present?

				end
			end

		end

	end
end

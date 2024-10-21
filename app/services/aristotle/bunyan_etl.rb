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

			begin
				events.each do |event|

					upsell_type = { '1' => 'post_sale', '2' => 'at_checkout', '3' => 'exit_checkout' }[src_event[:target_obj][:upsell_type].to_s] if ['upsell_offered', 'upsell_accepted'].include?( event.name ) && src_event[:target_obj_type] == 'Bazaar::UpsellOffer' && (src_event[:target_obj] || {})[:upsell_type].present?
					upsell_type = 'shop_page' if ['bundle_upsell_offered','bundle_upsell_accepted'].include?( event.name )

					if ['upsell_offered', 'bundle_upsell_offered'].include?( event.name )
						upsell_impression = Aristotle::UpsellImpression.where( impression_event: event ).first

						puts "event.src_client_id #{event.src_client_id}"
						if event.src_client_id.blank?
							puts "event.src_client_id BLANK!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
							puts "event.attributes.to_json #{event.attributes.to_json}\n\n"
							puts "src_event.to_json #{src_event.to_json}\n\n"
						end

						if upsell_impression.blank?
							end_at = Aristotle::Event.where( data_src: event.data_src, src_client_id: event.src_client_id, event_created_at: (event.event_created_at + 1.second)..Time.now, name: 'purchase' ).order(event_created_at: :asc).limit(1).pluck(:event_created_at).first
							end_at ||= Time.now

							upsell_impression = Aristotle::UpsellImpression.where.not( accepted_at: nil ).where( impression_event: nil, src_client_id: event.src_client_id, accepted_at: event.event_created_at..end_at, upsell_offer: event.offer, upsell_product: event.product ).first

							puts "upsell_impression HIT" if upsell_impression.present?
							puts "upsell_impression MISS" if upsell_impression.blank?
						end

						if upsell_impression.blank?
							upsell_impression = Aristotle::UpsellImpression.create!(
								customer: event.customer,
								from_offer: event.from_offer,
								from_product: event.from_product,
								upsell_offer: event.offer,
								upsell_product: event.product,
								src_client_id: event.src_client_id,
								src_created_at: event.event_created_at,
								event_data_src: event.data_src,
								impression_event: event,
								upsell_type: upsell_type,
							)
							puts "upsell_impression created"
						end

						# if the upsell was loaded, rather than created then update the from
						# details, and impression data
						upsell_impression.update(
							from_offer: event.from_offer,
							from_product: event.from_product,
							src_created_at: event.event_created_at,
							impression_event: event,
							upsell_type: upsell_type,
						)
						puts "upsell_impression impressed #{event.id} #{upsell_impression.attributes.to_json}"
					elsif ['bundle_upsell_accepted', 'upsell_accepted'].include?( event.name )

						upsell_impressions = Aristotle::UpsellImpression.where( accepted_event: event )
						if upsell_impressions.blank? && event.offer.present?

							if upsell_type == 'post_sale'

								start_at = event.event_created_at - 30.minutes

							else

								start_at = Aristotle::Event.where( data_src: event.data_src, src_client_id: event.src_client_id, event_created_at: Time.at(0)..(event.event_created_at - 1.second), name: 'purchase' ).order(event_created_at: :desc).limit(1).pluck(:event_created_at).first
								start_at ||= Time.at(0)
								start_at = start_at + 1.second

							end

							base_upsell_impressions = Aristotle::UpsellImpression.where(
								event_data_src: event.data_src,
								src_client_id: event.src_client_id,
								accepted_event: nil,
								src_created_at: start_at..event.event_created_at,
							)
							base_upsell_impressions = base_upsell_impressions.where( upsell_type: upsell_type ) if upsell_type.present?

							offer_upsell_impressions = base_upsell_impressions.where(
								upsell_offer: event.offer,
							)

							# when bundle_upsell_offered is fired, we don't know which specific
							# offer the custom will choose, just the product being offered.
							# So we need to potentially match the impression by only the product
							# but only if the offer lookup fails first
							product_upsell_impressions = base_upsell_impressions.where(
								upsell_product: event.product,
							)

							upsell_impressions = offer_upsell_impressions
							upsell_impressions = product_upsell_impressions.order(src_created_at: :desc).limit(1) if upsell_impressions.blank? && event.name == 'bundle_upsell_accepted'

							if upsell_impressions.blank?
								Aristotle::UpsellImpression.create!(
									customer: event.customer,
									from_offer: event.from_offer,
									from_product: event.from_product,
									upsell_offer: event.offer,
									upsell_product: event.product,
									src_client_id: event.src_client_id,
									src_created_at: nil,
									event_data_src: event.data_src,
									accepted_event: event,
									upsell_type: upsell_type,
								)
								upsell_impressions = Aristotle::UpsellImpression.where( accepted_event: event )
							end
						end

						# Mark as accepted
						upsell_impressions.update_all(
							accepted_event_id: event.id,
							accepted_at: event.event_created_at,
						)

						# If upsell offer is not present, then add it.
						if event.offer.present?
							upsell_impressions.where( upsell_offer: nil ).update_all(
								upsell_offer_id: event.offer.id,
								upsell_product_id: event.offer.product_id,
							)
						end
						puts "upsell_impressions accepted #{event.id} #{Aristotle::UpsellImpression.where( accepted_event: event ).collect(&:attributes).to_json}"
					elsif ['purchase','upsell'].include?( event.name )

						upsell_impressions = Aristotle::UpsellImpression.where( purchase_event: event )

						if upsell_impressions.blank? && event.name == 'upsell'
							accepted_events = Aristotle::Event.where( data_src: event.data_src, src_client_id: event.src_client_id, event_created_at: (event.event_created_at - 2.seconds)..(event.event_created_at + 2.seconds), name: 'upsell_accepted' )
							upsell_impressions = Aristotle::UpsellImpression.where( accepted_event: accepted_events )
						end

						src_order_id = nil
						if event.order.present?
							src_order_id = event.order.src_order_id
						else
							if event.src_target_obj_type == 'Bazaar::Order'
								src_order_id = event.src_target_obj_id
							elsif event.src_target_obj_type == 'Bazaar::Transaction'
								src_transaction = @bazaar_etl.extract_item( event.src_target_obj_type, event.src_target_obj_id )
								src_order_id = src_transaction[:parent_obj_id] if src_transaction[:parent_obj_type] == 'Bazaar::Order'

								raise Exception.new( "Unable to find order id from transaction #{src_transaction.to_json}" ) unless src_order_id.present?
							else
								raise Exception.new( "Invalid src_target_obj_type #{event.src_target_obj_type}" )
							end
						end
						raise Exception.new( "Unable to find order id from event #{event.attributes.to_json}" ) unless src_order_id.present?

						if upsell_impressions.blank?
							last_purchase_event = Aristotle::Event.where( data_src: event.data_src, src_client_id: event.src_client_id, event_created_at: Time.at(0)..(event.event_created_at - 1.second), name: 'purchase' ).order(event_created_at: :desc).limit(1).first
							start_at = last_purchase_event.try(:event_created_at) || Time.at(0)
							start_at = start_at + 1.second

							offer_ids = []

							if event.order.present?

								offer_ids = Aristotle::TransactionItem.where( order: event.order ).charge.pluck('distinct offer_id')

							else

								src_order = @bazaar_etl.extract_item( 'Bazaar::Order', src_order_id ) if src_order_id.present?

								if src_order.present?
									offers = src_order[:order_offers].collect{ |src_order_offer| @bazaar_etl.transform_offer( src_order_offer[:offer], data_src: event.data_src ) }
									offer_ids = offers.collect(&:id)
									# puts "the long way to get offer ids: #{offer_ids.to_json}"
								end

							end

							upsell_impressions = Aristotle::UpsellImpression.where(
								event_data_src: event.data_src,
								src_client_id: event.src_client_id,
								purchase_event: nil,
								# src_created_at: start_at..event.event_created_at,
								upsell_offer_id: offer_ids,
							).where("COALESCE(src_created_at,accepted_at) BETWEEN ? AND ?", start_at, event.event_created_at )

							# puts "last_purchase_event #{last_purchase_event.try(:attributes).to_json}"
							# puts "start_at #{start_at.to_json}"
						end

						upsell_impression_attributes = {
							purchase_event_id: event.id,
							order_data_src: event.data_src,
							src_order_id: src_order_id,
							purchased_at: event.event_created_at,
							customer_id: event.customer.try(:id),
						}

						if event.order.present?
							upsell_impression_attributes = upsell_impression_attributes.merge(
								order_data_src: event.order.data_src,
								order_id: event.order.id,
							)
						end

						update_count = upsell_impressions.update_all(upsell_impression_attributes)

						if event.order.present?
							puts " -> update_upsell_impressions start order"
							update_upsell_impressions( event.order.data_src, event.order.src_order_id )
						elsif event.src_target_obj_id.present? && event.name == 'purchase'
							puts " -> update_upsell_impressions start src_target_obj_id"
							update_upsell_impressions( event.data_src, event.src_target_obj_id )
						else
							puts " -> update_upsell_impressions start nope"
						end

						# puts "event.attributes.to_json #{event.attributes.to_json}"
						upsell_impressions_attributes = Aristotle::UpsellImpression.where( purchase_event: event ).collect(&:attributes)
						if upsell_impressions_attributes.present?
							puts "upsell_impressions purchased (done) #{event.id} #{event.src_event_id} #{upsell_impressions_attributes.to_json}"
						else
							puts "upsell_impressions purchased (none) #{event.id} #{event.src_event_id} #{upsell_impressions_attributes.to_json}"
						end
					end
				end
			rescue Exception => e
				puts "upsell_impressions exception #{events.collect(&:name).to_json} - #{events.collect(&:attributes).to_json}"
				puts "--------------------------"
				puts e.message
				puts e.backtrace.join("\n")
				puts "--------------------------\n\n\n"
				raise e unless Rails.env.production?
				NewRelic::Agent.notice_error(e) if defined?( NewRelic )
			end


			puts " -> saving done"
			events
		end

		def process_src_event( src_event, src_client )
			src_event_id = src_event.delete(:id)

			src_event[:target_obj] ||= @bazaar_etl.extract_item( src_event[:target_obj_type], src_event[:target_obj_id] )

			puts "process_src_event	#{src_event[:created_at]}	#{src_event[:name]}	#{src_event_id}"#	#{src_event[:target_obj_type]}	#{src_event[:target_obj_id]}	#{src_event[:target_obj].present?}"

			event = Event.where( data_src: @data_src, src_event_id: src_event_id, name: src_event[:name] ).first if @options[:allow_updates]
			if event.present?
				puts " -> update"
			else
				puts " -> new"
			end

			if src_event[:page_params].present?
				page_params = Rack::Utils.parse_nested_query(src_event[:page_params]).deep_symbolize_keys rescue nil
			end
			page_params ||= {}

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
					if target_obj[:src_product_id] && event.respond_to?(:from_product)
						event.from_product 	||= Product.where( data_src: @bazaar_data_sources, src_product_id: "Bazaar::Product\##{target_obj[:src_product_id]}" ).first
					end

					if target_obj[:src_offer_id] && event.respond_to?(:from_offer)
						event.from_offer		||= Offer.where( data_src: @bazaar_data_sources, src_offer_id: "Bazaar::Offer\##{target_obj[:src_offer_id]}" ).first
						event.from_offer		||= @bazaar_etl.transform_offer( target_obj[:src_offer], data_src: event.data_src ) if target_obj[:src_offer].present?
						event.from_product	||= event.from_offer.try(:product)
					end

					if target_obj[:offer]
						event.offer 	||= Offer.where( data_src: @bazaar_data_sources, src_offer_id: "Bazaar::Offer\##{target_obj[:offer_id]}" ).first
						event.offer 	||= @bazaar_etl.transform_offer( target_obj[:offer], data_src: event.data_src )
					end

					if target_obj[:upsell]
						event.offer 	||= Offer.where( data_src: @bazaar_data_sources, src_offer_id: "Bazaar::Offer\##{target_obj[:upsell][:offer_id]}" ).first
						event.offer 	||= @bazaar_etl.transform_offer( target_obj[:upsell][:offer], data_src: event.data_src )
					end

					if event.offer.blank?
						puts "target_obj #{target_obj.to_json}"
						raise Exception.new "offer does not exist for Bazaar::UpsellOffer target object #{target_obj.to_json}"
					end
				when 'Bazaar::Transaction'

					event.order = Order.where( data_src: @bazaar_data_sources, src_order_id: target_obj[:parent_obj_id] ).first if target_obj[:parent_obj_type] == 'Bazaar::Order'

				when 'BazaarMediaRelation'
					event.from_product	||= Product.where( data_src: @bazaar_data_sources, src_product_id: "Bazaar::Product\##{target_obj[:bazaar_media_from][:product_id]}" ).first if target_obj[:bazaar_media_to][:product_id]
					# event.from_offer 	||= Offer.where( data_src: @bazaar_data_sources, src_offer_id: "Bazaar::Offer\##{target_obj[:bazaar_media_from][:non_recurring_offer_id]}" ).first if target_obj[:bazaar_media_to][:non_recurring_offer_id]

					event.product	||= Product.where( data_src: @bazaar_data_sources, src_product_id: "Bazaar::Product\##{target_obj[:bazaar_media_to][:product_id]}" ).first if target_obj[:bazaar_media_to][:product_id]
					# event.offer 	||= Offer.where( data_src: @bazaar_data_sources, src_offer_id: "Bazaar::Offer\##{target_obj[:bazaar_media_to][:non_recurring_offer_id]}" ).first if target_obj[:bazaar_media_to][:non_recurring_offer_id]
				end

			end

			if ['bundle_upsell_add_cart', 'bundle_upsell_accepted'].include?(event.name) && page_params[:offer_id].present?
				event.product	= nil
				event.offer 	= Offer.where( data_src: @bazaar_data_sources, src_offer_id: "Bazaar::Offer\##{page_params[:offer_id]}" ).first
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

			if src_event[:target_obj].present?
				case event.src_target_obj_type
				when 'Bazaar::Order'
					if src_event[:target_obj][:order_offers].present?
						src_event[:target_obj][:order_offers].each do |src_order_offer|
							events = events + process_src_event( src_event.merge( id: src_event_id, name: "#{src_event[:name]}::offer", target_obj_id: src_order_offer[:offer_id], target_obj_type: 'Bazaar::Offer', target_obj: nil ), src_client )
						end
					end
				when 'Bazaar::Cart'
					if src_event[:target_obj][:cart_offers].present?
						src_event[:target_obj][:cart_offers].each do |src_cart_offer|
							events = events + process_src_event( src_event.merge( id: src_event_id, name: "#{src_event[:name]}::offer", target_obj_id: src_cart_offer[:offer_id], target_obj_type: 'Bazaar::Offer', target_obj: nil ), src_client )
						end
					end
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


			excluded_event_names = args[:excluded_event_names] || ['pageview', '404', 'get-client']

			qualified_events = Aristotle::Event.where( data_src: @data_src ).where.not( name: excluded_event_names )
			qualified_events = qualified_events.where("name ilike '%#{args[:ilike_name]}%'") if args[:ilike_name].present?
			qualified_events = qualified_events.where("name ilike '#{args[:name_starts_with]}%'") if args[:name_starts_with].present?
			qualified_events = qualified_events.where( name: args[:name_is] ) if args[:name_is].present?
			qualified_events = qualified_events.where("category = '#{args[:category]}'") if args[:category].present?
			qualified_events = qualified_events.where("referrer_path ilike '#{args[:referrer_path_starts_with]}%'") if args[:referrer_path_starts_with].present?
			qualified_events = qualified_events.where("page_path ilike '#{args[:page_path_starts_with]}%'") if args[:page_path_starts_with].present?

			last_event_id = args[:last_event_id]
			last_event_id ||= qualified_events.where( event_created_at: 1.month.ago..Time.now ).maximum('src_event_id::bigint')
			last_event_id ||= qualified_events.where( event_created_at: 1.month.ago..Time.now ).maximum('src_event_id')
			last_event_id ||= qualified_events.maximum('src_event_id')
			last_event_id ||= qualified_events.last.try(:src_event_id)
			last_event_id ||= 0

			max_created_at = args[:max_created_at] || 1.day.ago
			min_created_at = args[:min_created_at] || Time.at(0)


			event_query_filters = ""
			event_query_filters = event_query_filters + "AND bunyan_events.name ilike '%#{args[:ilike_name]}%'" if args[:ilike_name].present?
			event_query_filters = event_query_filters + "AND bunyan_events.name ilike '#{args[:name_starts_with]}%'" if args[:name_starts_with].present?
			event_query_filters = event_query_filters + "AND bunyan_events.name = '#{args[:name_is]}'" if args[:name_is].present? && args[:name_is].is_a?(String)
			event_query_filters = event_query_filters + "AND bunyan_events.name IN ('#{args[:name_is].join("', '")}')" if args[:name_is].present? && args[:name_is].is_a?(Array)
			event_query_filters = event_query_filters + "AND bunyan_events.category = '#{args[:category]}'" if args[:category].present?
			event_query_filters = event_query_filters + "AND bunyan_events.referrer_path ilike '#{args[:referrer_path_starts_with]}%'" if args[:referrer_path_starts_with].present?
			event_query_filters = event_query_filters + "AND bunyan_events.page_path ilike '#{args[:page_path_starts_with]}%'" if args[:page_path_starts_with].present?


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

			puts "event_query #{event_query}"

			page_i = 1
			while( true ) do
				puts "Page #{page_i} (last_event_id: #{last_event_id}) - Loading"
				event_rows = exec_query( event_query, last_event_id: last_event_id.to_i, max_created_at: max_created_at, min_created_at: min_created_at, excluded_event_names: excluded_event_names )
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

			last_event_id

		end

		def update_upsell_impressions( data_src, src_order_id )
			unless src_order_id.present? && data_src.present?
				puts " -> update_upsell_impressions #{data_src} #{src_order_id} ID Not Present"
				return
			end
			puts " -> update_upsell_impressions #{data_src} #{src_order_id}"

			upsell_impressions = Aristotle::UpsellImpression.where( order_data_src: data_src, src_order_id: src_order_id )
			order_transaction_items = Aristotle::TransactionItem.where( data_src: data_src, src_order_id: src_order_id )

			puts " -> update_upsell_impressions count #{upsell_impressions.count} #{order_transaction_items.count}"
			puts " -> update_upsell_impressions upsell_impressions hit #{upsell_impressions.count}" if upsell_impressions.present?
			# puts " -> update_upsell_impressions order_transaction_items hit #{order_transaction_items.count}" if order_transaction_items.present?

			upsell_impressions_changes = {
				order_charge_sub_total: order_transaction_items.charge.sum(:sub_total),
				order_refund_sub_total: order_transaction_items.refund.sum(:sub_total),
				order_upsell_count: upsell_impressions.count,
			}
			upsell_impressions_changes_count = upsell_impressions.update_all( upsell_impressions_changes )
			puts "     upsell_impressions #{upsell_impressions_changes.to_json} #{upsell_impressions_changes_count}" if upsell_impressions.present?

			upsell_impressions.each do |upsell_impression|

				offer_transaction_items = order_transaction_items.where( offer_id: upsell_impression.upsell_offer_id )
				upsell_impression.subscription_id = offer_transaction_items.where.not( subscription_id: nil ).limit(1).pluck(:subscription_id).first
				upsell_impression.offer_charge_sub_total = offer_transaction_items.charge.sum(:sub_total)
				upsell_impression.offer_refund_sub_total = offer_transaction_items.refund.sum(:sub_total)
				puts "     upsell_impression #{upsell_impression.changes.to_json}"
				upsell_impression.save

			end



			# Update LTV Fields
			subscription_ids = order_transaction_items.where.not( subscription_id: nil ).pluck(:subscription_id)
			lifetime_order_ids = Aristotle::TransactionItem.where( subscription_id: subscription_ids ).pluck('distinct order_id')

			lifetime_transaction_items = Aristotle::TransactionItem.where( order_id: lifetime_order_ids )
			subscription_upsell_impressions = Aristotle::UpsellImpression.where( subscription_id: subscription_ids )
			puts " -> update_upsell_impressions ltv count #{subscription_upsell_impressions.count} #{lifetime_transaction_items.count}"
			puts " -> update_upsell_impressions subscription_upsell_impressions hit #{subscription_upsell_impressions.count}" if subscription_upsell_impressions.present?
			# puts " -> update_upsell_impressions lifetime_transaction_items hit #{lifetime_transaction_items.count}" if lifetime_transaction_items.present?

			subscription_upsell_impressions_changes = {
				order_ltv_charge_sub_total: lifetime_transaction_items.charge.sum(:sub_total),
				order_ltv_refund_sub_total: lifetime_transaction_items.refund.sum(:sub_total),
			}
			subscription_upsell_impressions_changes_count = subscription_upsell_impressions.update_all( subscription_upsell_impressions_changes )
			puts "     subscription_upsell_impressions #{subscription_upsell_impressions_changes.to_json} #{subscription_upsell_impressions_changes_count}" if subscription_upsell_impressions.present?


			subscription_upsell_impressions.each do |upsell_impression|
				offer_transaction_items = Aristotle::TransactionItem.where( subscription_id: upsell_impression.subscription_id, offer_id: upsell_impression.upsell_offer_id )
				upsell_impression.offer_ltv_charge_sub_total = offer_transaction_items.charge.sum(:sub_total)
				upsell_impression.offer_ltv_refund_sub_total = offer_transaction_items.refund.sum(:sub_total)
				puts "     subscription_upsell_impression #{upsell_impression.changes.to_json}"
				upsell_impression.save
			end

		end

	end
end

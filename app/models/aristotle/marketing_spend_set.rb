module Aristotle
	class MarketingSpendSet < ApplicationRecord

		has_many :marketing_spends, dependent: :destroy

		def process_totals_into_marketing_spends_metrics
			distributions = {}
			total_attributes = [:spend_total, :sent_count_total, :open_count_total, :open_uniq_count_total, :click_count_total, :click_uniq_count_total, :purchase_count_total, :purchase_uniq_count_total, :purchase_value_total]
			total_attributes.each do |total_attribute|
				daily_attribute = total_attribute.to_s.gsub('_total','')

				total_attribute_value = self.try(total_attribute)

				daily_attribute_distributions = []
				unless total_attribute_value.nil? || number_of_days.to_i <= 0

					daily_attribute_value = (total_attribute_value / number_of_days.to_f).floor
					daily_attribute_remainder = total_attribute_value % number_of_days.to_f
					daily_attribute_distributions = (1..number_of_days).to_a.fill(daily_attribute_value)

					remainder_increment = 1
					remainder_increment = -1 if daily_attribute_remainder < 0

					daily_attribute_remainder.to_i.times do |i|
						daily_attribute_distributions[i] = daily_attribute_distributions[i] + remainder_increment
					end
				end

				distributions[daily_attribute] = daily_attribute_distributions
			end

			(0..(number_of_days-1)).collect do |i|
				row = {}

				distributions.keys.each do |daily_attribute|
					row[daily_attribute] = distributions[daily_attribute][i]
				end

				row
			end
		end

		def sync!
			self.marketing_spends.destroy_all
			return if number_of_days.nil?
			next_start_at = self.start_at
			next_end_at = Time.at((next_start_at.to_f - 0.000001).round(6)) + 1.day

			process_totals_into_marketing_spends_metrics.each do |marketing_spends_metrics|
				marketing_spend = self.marketing_spends.new(
					start_at: next_start_at,
					end_at: next_end_at,
					source: source,
					medium: medium,
					content: content,
					term: term,
					campaign: campaign,
					data_src: data_src,
					src_account_id: src_account_id,
					src_account_name: src_account_name,
					src_campaign_id: src_campaign_id,
					purpose: purpose,
					research_type: research_type,
					campaign_id: campaign_id,
					email_campaign_id: email_campaign_id,
				)

				marketing_spend.is_manual = is_manual if marketing_spend.respond_to?(:is_manual=) && self.respond_to?(:is_manual)

				marketing_spends_metrics.each do |attr,val|
					marketing_spend.try("#{attr}=",val)
				end

				marketing_spend.save!

				next_start_at = next_start_at + 1.day
				next_end_at = next_end_at + 1.day
			end
		end

	end
end

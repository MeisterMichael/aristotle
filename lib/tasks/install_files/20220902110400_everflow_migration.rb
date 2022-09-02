class EverflowMigration < ActiveRecord::Migration[5.1]
	def change

		change_table :aristotle_channel_partners do |t|
			t.string			:everflow_channel_partner_id
			t.index [:everflow_channel_partner_id]
		end

	end
end

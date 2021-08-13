class ReviewsMigration < ActiveRecord::Migration[5.1]
	def change

		create_table :aristotle_reviews do |t|
			t.belongs_to	:customer
			t.belongs_to	:location
			t.belongs_to	:product
			t.belongs_to	:offer
			t.integer			:status, default: 1
			t.string			:data_src
			t.string			:src_review_id
			t.string			:referrer_src
			t.datetime		:reviewed_at
			t.integer			:rating, default: nil
			t.integer			:review_words, default: 0
			t.timestamps

			t.index [:reviewed_at, :referrer_src, :product_id], name: :index_aristotle_reviews_on_at_and_referrer_and_product
		end

	end
end

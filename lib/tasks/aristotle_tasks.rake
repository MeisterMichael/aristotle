
# desc "Explaining what the task does"
namespace :aristotle do

	task :install do
		puts "Installing Aristotle..... But, Why?"

		files = {
			'application_report' => 'app/reports/',
		}

		files.each do |filename, path|
			puts "installing: #{path}/#{filename}"

			source = File.join( Gem.loaded_specs["aristotle"].full_gem_path, "lib/tasks/install_files", filename )
    		if path == :root
    			target = File.join( Rails.root, filename )
    		else
    			target = File.join( Rails.root, path, filename )
    		end
    		FileUtils.cp_r source, target
		end

		# migrations
		migrations = [
			'aristotle_migration.rb',
		]

		prefix = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i

		migrations.each do |filename|
			source = File.join( Gem.loaded_specs["aristotle"].full_gem_path, "lib/tasks/install_files", filename )

    		target = File.join( Rails.root, 'db/migrate', "#{prefix}_#{filename}" )

    		FileUtils.cp_r source, target
    		prefix += 1
		end

	end
end

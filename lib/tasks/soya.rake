namespace :soya do
    desc "Fetch a SOyA structure (default: the current version of Did) and use it if the fixtures pass; FORCE=1 skips the check"
    task :fetch, [:ref] => :environment do |_task, args|
        ok = DidLint::StructureUpdate.new.run(args[:ref].presence || "Did", force: ENV["FORCE"] == "1")
        exit(1) unless ok
    end

    desc "Go back to the pinned SOyA structure"
    task reset: :environment do
        DidLint::Structure.reset
        puts "now using the pinned structure #{DidLint::Structure.active_dri}"
    end

    desc "Show which SOyA structure is in use"
    task status: :environment do
        active = DidLint::Structure.active_dri
        pinned = DidLint::Structure.pinned_dri
        puts "in use: #{active} (#{active == pinned ? 'pinned' : 'fetched'})"
        puts "pinned: #{pinned}"
        puts "fetched copies: #{DidLint::Structure.runtime_dir}"
    end
end

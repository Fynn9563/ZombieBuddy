def author_slug(name, id)
  slug = name.downcase.gsub(/[^[[:alnum:]]]+/, "-").gsub(/^-+|-+$/, "")
  slug.empty? ? id.to_s : slug
end

namespace :authors do
  desc "Add a new author to the database"
  task :add do
    _, id, name, key = ARGV
    msg = "Usage: rake authors:add <id> <name> <key>"
    raise msg unless id =~ /^\d+$/
    raise msg unless name.size > 0
    raise msg unless key.size == 64

    path = File.join("authors", "#{author_slug(name, id)}.json")
    raise "#{path} already exists" if File.exist?(path)

    File.write(path, JSON.pretty_generate("id" => id.to_i, "name" => name, "keys" => [key]))

    Rake::Task["authors:sign"].invoke
    exit 0
  end

  desc 'aggregate authors/*.json into authors.json and sign it'
  task :sign do
    authors = Dir["authors/*.json"].map { |f| JSON.parse(File.read(f)) }
    authors = authors.sort_by { |a| a['name'].downcase }
    authors = authors.map { |a| { "name" => a['name'], "id" => a['id'], "keys" => a['keys'] } }

    data = JSON.parse(File.read("authors.json"))

    if authors == data['authors']
      puts "authors.json unchanged, skipping sign"
      next
    end

    data['updated_at'] = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")

    authors_block = authors.map { |a| "    #{JSON.generate(a)}" }.join(",\n")
    File.write("authors.json", <<~JSON)
      {
        "updated_at": #{JSON.generate(data['updated_at'])},
        "authors": [
      #{authors_block}
        ],
        "signature": #{JSON.generate(data['signature'])}
      }
    JSON

    Dir.chdir("java") do
      sh "gradle signAuthorsJson"
    end
  end
end

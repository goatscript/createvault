require_relative 'vault'

=begin
PreReqs:
- ChefDK needs to be installed on the machine before running the script.
- Needs access to the Chef server
- Creaet a YAML file for the project.
=end

puts "What is the path to the yaml file?"
path = gets.chomp

project = Vault.new

# Upload the yaml and extract information from the YAML file
settings = YAML.load_file("#{path}")
project.dirname = settings["config"]["dirname"]
project.ticket = settings["config"]["ticket"]
project.client = settings["config"]["client"]
project.servers = settings["config"]["servers"]
project.se = settings["config"]["se"]
project.pathway = settings["config"]["pathway"]

# Create the JSON directory if missing
FileUtils.mkdir_p("#{project.dirname}") unless File.directory?("#{project.dirname}")

# Call the method to create the JSON file, which is used later to create the Chef Vault.
project.json_creator

# Create the Chef Vault from the previously created JSON file.
project.knife_create

# Update the Chef Vault with the associated servers
project.knife_update

# Creates the wrapper cookbook.
project.cookbook_create

# Modifies the default.rb adding the ntp, autofs, motd and immutable cookbooks to the run list
open("#{project.pathway}wrapper-#{project.ticket}/recipes/default.rb", 'a') { |file|
  file << "include_recipe 'gsmotd'\n"
  file << "include_recipe 'autofs'\n"
  file << "include_recipe 'gsntp'\n"
  file << "include_recipe 'immutable'\n"
}

# Modifies the wrapper cookbook metadata file adding ntp, autofs, motd, and immutable cookbooks as dependencies
open("#{project.pathway}wrapper-#{project.ticket}/metadata.rb", 'a') { |file|
  file << "depends 'gsmotd'\n"
  file << "depends 'autofs'\n"
  file << "depends 'gsntp'\n"
  file << "depends 'immutable'\n"
}

# Creates the default attributes file
project.attribute_create("default")

# Adds the override attributes to the default attributes file
open("#{project.pathway}wrapper-#{project.ticket}/attributes/default.rb", 'a') { |file|
  file << %Q(#override attributes for immutable\n\n)
  file << %Q(default[:immutable][:machine_type] = "SMAP machine"\n)
  file << %Q(default[:immutable][:ticket_number] = "#{project.ticket}"\n)
  file << %Q(default[:immutable][:client] = "#{project.client}"\n)
  file << %Q(default[:immutable][:immutable_file] = "/root/machine.lock"\n)
  file << %Q(default[:immutable][:vault_info] = "#{project.ticket}"\n)
  file << %Q(default[:immutable][:se] = "nate delgado"\n)
  file << %Q(\n#override attributes for gsmotd\n\n)
  file << %Q(default[:gsmotd][:ticket] = "#{project.ticket}"\n)
  file << %Q(default[:gsmotd][:se] = "#{project.se}"\n)
  file << %Q(default[:gsmotd][:client] = "#{project.client}"\n)
}

# Uploads the cookbook to the Chef server
project.cookbook_upload

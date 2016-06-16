require 'securerandom'
require 'json'
require 'openssl'
require 'fileutils'
require 'yaml'

class Vault

    attr_accessor :dirname, :ticket, :servers, :client, :se, :pathway
    
    # Creates a unique identifier
    def unique_creator
        time = Time.now.to_i
        phrase = SecureRandom.hex
        unique = OpenSSL::Digest::MD5.hexdigest("#{phrase}") + "#{time}"
    end
    
    # Creates a JSON file containing ticket information and the unique identifier
    def json_creator
        unique = unique_creator()
        tempJson = {
                "id" => "#{@ticket}",
                "data" => "#{unique}"
        }
        File.open("#{@dirname}#{@ticket}.json", File::WRONLY|File::CREAT|File::EXCL) do |file|
                file.write(JSON.pretty_generate(tempJson))
        end
    end

    # Creates the Chef Vault
    def knife_create
        cmd = %Q(knife vault create machine_lock #{@ticket} --json #{@dirname}#{@ticket}.json --mode client)
        system(cmd)
    end

    # Updates the servers in Chef Vault
    def knife_update
        @servers.each do |server|
          cmd = %Q(knife vault update machine_lock #{@ticket} -S "name:#{server}" --mode client)
          system(cmd)
        end
    end

    # Deletes the Chef Vault
    def knife_delete
        cmd = %Q(knife vault delete machine_lock #{@ticket} -S "name:#{@servers}" --mode client)
        system(cmd)
    end

    # Creates the wrapper cookbook
    def cookbook_create
        cmd = %Q(chef generate cookbook /root/chef-repo/cookbooks/wrapper-#{@ticket})
        system(cmd)
    end

    # Uploads the cookbook
    def cookbook_upload
        cmd = %Q(knife cookbook upload wrapper-#{@ticket})
        system(cmd)
    end

    # Appends files
    def append_file(file, append)
        open("#{file}", 'a') { file
            file << "#{append}"
        }
    end

    # Creates an attributes file
    def attribute_create(file)
        cmd = %Q(chef generate attribute /root/chef-repo/cookbooks/wrapper-#{@ticket} #{file})
        system(cmd)
    end
end
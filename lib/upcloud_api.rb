require "timeout"

require "httparty"

# Class to serve as a Ruby API for the UpCloud HTTP API
class UpcloudApi
  # @param user [String] Upcloud API account
  # @param password [String] Upcloud API password
  def initialize(user, password)
    @user = user
    @password = password
    @auth = { username: @user, password: @password }
  end

  # Tests that authentication to Upcloud works.
  #
  # This is not required to use, as authentication is used
  # with HTTP basic auth with each request.
  #
  # Calls GET /1.2/server
  #
  # @return true in success, false if not.
  def login
    response = get "server"
    response.code == 200
  end

  # Returns available server configurations.
  #
  # Calls GET /1.2/server_size.
  #
  # @return array of server size hashes
  #
  # @example Return hash
  #   {
  #     "core_number": "1",
  #     "memory_amount": "512"
  #   }
  def server_configurations
    response = get "server_size"
    response["server_sizes"]["server_size"]
  end

  # Returns available credits.
  #
  # Calls GET /1.2/acccount
  #
  # @return available credits in the account as a string.
  def account_information
    response = get "account"
    data = JSON.parse response.body
    data["account"]["credits"]
  end

  # Lists servers associated with the account.
  #
  # Calls GET /1.2/server.
  #
  # @return array of servers with following values or empty array if no servers found.
  #
  # @example Return values
  #   - zone
  #   - core_number
  #   - title
  #   - hostname
  #   - memory_amount
  #   - uuid
  #   - state
  def servers
    response = get "server"
    data = JSON.parse response.body
    data["servers"]["server"]
  end

  # Shows details of a server.
  #
  # Calls GET /1.2/server/_uuid_.
  #
  # @param uuid from UpcloudApi#servers
  #
  # @return hash of server details or nil
  #
  # @example Return values
  #   {
  #    "boot_order"         => "cdrom,disk",
  #    "core_number"        => "3",
  #    "firewall"           => "off",
  #    "hostname"           => "dummy",
  #    "ip_addresses"       => {
  #      "ip_address" => [
  #        {
  #          "access" => "private",
  #          "address"            => "192.168.0.1",
  #         "family"             => "IPv4"
  #        },
  #        {
  #          "access"            => "public",
  #          "address"            => "::1",
  #          "family"             => "IPv6"
  #        },
  #        {
  #          "access"            => "public",
  #          "address"            => "198.51.100.1",
  #          "family"             => "IPv4"
  #        }
  #      ]
  #    },
  #    "license"            => 0,
  #    "memory_amount"      => "3072",
  #    "nic_model"          => "virtio",
  #    "plan"               => "custom",
  #    "state"              => "stopped",
  #    "storage_devices"    => {
  #      "storage_device" => [
  #        {
  #          "address" => "virtio:1",
  #          "storage"            => "storage_uuid",
  #          "storage_size"       => 10,
  #          "storage_title"      => "Disk name",
  #          "type"               => "disk"
  #        }
  #      ]
  #    },
  #    "tags"               => {"tag" => []},
  #    "timezone"           => "UTC",
  #    "title"              => "Server name",
  #    "uuid"               => "uuid",
  #    "video_model"        => "cirrus",
  #    "vnc"                => "off",
  #    "vnc_password"       => "1234",
  #    "zone"               => "de-fra1"
  #   }
  def server_details(uuid)
    response = get "server/#{uuid}"
    data = JSON.parse response.body

    return nil if data["server"].nil?

    data["server"]
  end

  # Creates new server from template.
  #
  # Calls POST /1.2/server.
  #
  # @example Storage devices should be array of hashes containing following data
  #   {
  #     "action"  => "clone"          # Can be "create", "clone" or "attach"
  #     "storage" => template_uuid,   # Should be passed only for "clone" or "attach"
  #     "title"   => disk_name,       # Name of the storage,
  #     "tier"    => "maxiops",       # No sense using HDD any more
  #   }
  #
  # @param plan [String] Preconfigured plan for the server. If nil, a custom plan will be created from input data, otherwise this overrides custom configuration.
  #   Predefined plans can be fetched with {#plans}.
  #
  # @example login_user should be following hash or nil
  #   {
  #     "username": "upclouduser",
  #     "ssh_keys": {
  #       "ssh_key": [
  #          "ssh-rsa AAAAB3NzaC1yc2EAA[...]ptshi44x user@some.host",
  #          "ssh-dss AAAAB3NzaC1kc3MAA[...]VHRzAA== someuser@some.other.host"
  #        ]
  #     }
  #   }
  #
  # @param ip_addresses should be an array containing :public, :private and/or :ipv6. It defaults to
  # :all, which means the server will get public IPv4, private IPv4 and public IPv6 addresses.
  #
  # @param other [Hash] Other optional arguments create_server API call takes. See Upcloud’s documentation for possible values.
  #
  # @return HTTParty response object.
  def create_server(zone: "fi-hel1", title:, hostname:, core_number: 1,
                    memory_amount: 1024, storage_devices:, ip_addresses: :all,
                    plan: nil, login_user: nil, other: nil)
    data = {
      "server" => {
        "zone" => zone,
        "title" => title,
        "hostname" => hostname,
        "storage_devices" => { "storage_device" => storage_devices }
      }
    }

    if plan.nil?
        data["server"]["core_number"] = core_number
        data["server"]["memory_amount"] = memory_amount
    else
        data["server"]["plan"] = plan
    end

    if ip_addresses != :all
      ips = []
      ips << { "access" => "public", "family" => "IPv4" } if ip_addresses.include? :public
      ips << { "access" => "private", "family" => "IPv4" } if ip_addresses.include? :private
      ips << { "access" => "public", "family" => "IPv6" } if ip_addresses.include? :ipv6

      data["server"]["ip_addresses"] = {}
      data["server"]["ip_addresses"]["ip_address"] = ips
    end

    unless login_user.nil?
        data["login_user"] = login_user
    end

    unless other.nil?
        data.merge! other
    end

    json = JSON.generate data
    response = post "server", json
    response
  end

  # Modifies existing server.
  #
  # In order to modify a server, the server must be stopped first.
  #
  # Calls PUT /1.2/server/_server_uuid_.
  #
  # @param server_uuid [String] UUID of the server that will be modified.
  # @param params [Hash] Hash of params that will be passed to be changed.
  #
  # @return HTTParty response object.
  def modify_server(server_uuid, params)
    data = { "server" => params }
    json = JSON.generate data
    response = put "server/#{server_uuid}", json

    response
  end

  # Deletes a server.
  #
  # In order to delete a server, the server must be stopped first.
  #
  # Calls DELETE /1.2/server/_server_uuid_.
  #
  # @return HTTParty response object.
  def delete_server(server_uuid)
    response = delete "server/#{server_uuid}"

    response
  end

  # Starts server that is shut down.
  #
  # Calls POST /1.2/server/_server_uuid_/start.
  #
  # @param server_uuid UUID of the server.
  #
  # @return HTTParty response object.
  def start_server(server_uuid)
    response = post "server/#{server_uuid}/start"

    response
  end

  # Shuts down a server that is currently running.
  #
  # Calls POST /1.2/server/_uuid_/stop.
  #
  # Hard shutdown means practically same as taking the power cable
  # off from the computer. Soft shutdown sends ACPI signal to the server,
  # which should then automatically handle shutdown routines by itself.
  # If timeout is given, server will be forcibly shut down after the
  # timeout has expired.
  #
  # @param server_uuid UUID of the server
  # @param type Type of the shutdown. Available types are :hard and :soft.
  #   Defaults to :soft.
  # @param timeout Time after server will be hard stopped if it did not
  #   close cleanly. Only affects :soft type.
  # @param asynchronous If false, this call will wait until the server
  #   has really stopped.
  #
  # @raise Timeout::Error in case server does not shut down in 300
  #   seconds in non-asynchronous mode.
  #
  # @return HTTParty response object if server was removed successfully or request is asynchronous and nil otherwise
  def stop_server(server_uuid, type: :soft, timeout: nil, asynchronous: false)
    data = {
      "stop_server" => {
        "stop_type" => type.to_s
      }
    }
    data["stop_server"]["timeout"] = timeout unless timeout.nil?

    json = JSON.generate data

    response = post "server/#{server_uuid}/stop", json

    return response if asynchronous

    Timeout.timeout 300 do
      loop do
        details = server_details server_uuid
        return response if details.nil?
        return response if details["state"] == "stopped"
      end
    end

    nil
  end

  # Restarts a server that is currently running.
  #
  # Calls POST /1.2/server/_uuid_/restart.
  #
  # Hard shutdown means practically same as taking the power cable
  # off from the computer. Soft shutdown sends ACPI signal to the server,
  # which should then automatically handle shutdown routines by itself.
  # If timeout is given, server will be forcibly shut down after the
  # timeout has expired.
  #
  # @param server_uuid UUID of the server
  # @param type Type of the shutdown. Available types are :hard and :soft.
  #   Defaults to :soft.
  # @param timeout Time after server will be hard stopped if it did not
  #   close cleanly. Only affects :soft type.
  # @param timeout_action What will happen when timeout happens.
  #   :destroy hard stops the server and :ignore stops the operation
  #   if timeout happens. Default is :ignore.
  #
  # @return HTTParty response object.
  def restart_server(server_uuid, type: :soft, timeout: nil, timeout_action: :ignore)
    data = {
      "restart_server" => {
        "stop_type" => type.to_s,
        "timeout_action" => timeout_action
      }
    }
    data["restart_server"]["timeout"] = timeout unless timeout.nil?

    json = JSON.generate data

    response = post "server/#{server_uuid}/restart", json

    response
  end

  # Lists all storages or storages matching to given type.
  #
  # Calls GET /1.2/storage or /1.2/storage/_type_.
  #
  # @example Available types
  #   - public
  #   - private
  #   - normal
  #   - backup
  #   - cdrom
  #   - template
  #   - favorite
  #
  # @param type Type of the storages to be returned on nil.
  #
  # @return array of storages, inside "storage" key in the API or empty array if none found.
  def storages(type: nil)
    response = get(type && "storage/#{type}" || "storage")
    data = JSON.parse response.body
    data["storages"]["storage"]
  end

  # Shows detailed information of single storage.
  #
  # Calls GET /1.2/storage/_uuid_.
  #
  # @param storage_uuid UUID of the storage.
  #
  # @return hash of following storage details or nil
  # @example Return values
  #   {
  #     "access"  => "public",
  #     "license" => 0,
  #     "servers" => {
  #         "server"=> []
  #       },
  #     "size"    => 1,
  #     "state"   => "online",
  #     "title"   => "Windows Server 2003 R2 Standard (CD 1)",
  #     "type"    => "cdrom",
  #     "uuid"    => "01000000-0000-4000-8000-000010010101"
  #   }
  def storage_details(storage_uuid)
    response = get "storage/#{storage_uuid}"
    data = JSON.parse response.body

    return nil if data["storage"].nil?

    data["storage"]
  end

  # Creates new storage.
  #
  # Calls POST /1.2/storage.
  #
  # @example backup_rule should be hash with following attributes
  #   - interval # allowed values: daily / mon / tue / wed / thu / fri / sat / sun
  #   - time # allowed values: 0000-2359
  #   - retention # How many days backup will be kept. Allowed values: 1-1095
  #
  # @param size Size of the storage in gigabytes
  # @param tier Type of the disk. maxiops is SSD powered disk, other
  #   allowed value is "hdd"
  # @param title Name of the disk
  # @param zone Where the disk will reside. Needs to be within same zone
  #   with the server
  # @param backup_rule Hash of backup information. If not given, no
  #   backups will be automatically created.
  #
  # @return HTTParty response object.
  def create_storage(size:, tier: "maxiops", title:, zone: "fi-hel1",
                     backup_rule: nil)
    data = {
      "storage" => {
        "size" => size,
        "tier" => tier,
        "title" => title,
        "zone" => zone
      }
    }
    data["storage"]["backup_rule"] = backup_rule unless backup_rule.nil?

    json = JSON.generate data
    response = post "storage", json

    response
  end

  # Modifies existing storage.
  #
  # Calls PUT /1.2/storage/_uuid_.
  #
  # @example backup_rule should be hash with following attributes
  #   - interval # allowed values: daily / mon / tue / wed / thu / fri / sat / sun
  #   - time # allowed values: 0000-2359
  #   - retention # How many days backup will be kept. Allowed values: 1-1095
  #
  # @param storage_uuid UUID of the storage that will be modified
  # @param size Size of the storage in gigabytes
  # @param title Name of the disk
  # @param backup_rule Hash of backup information. If not given, no
  #   backups will be automatically created.
  #
  # @return HTTParty response object.
  def modify_storage(storage_uuid, size:, title:, backup_rule: nil)
    data = {
      "storage" => {
        "size" => size,
        "title" => title
      }
    }
    data["storage"]["backup_rule"] = backup_rule unless backup_rule.nil?

    json = JSON.generate data

    response = put "storage/#{storage_uuid}", json

    response
  end

  # Clones existing storage.
  #
  # This operation is asynchronous.
  #
  # Calls POST /1.2/storage/_uuid_/clone.
  #
  # @param storage_uuid UUID of the storage that will be modified
  # @param tier Type of the disk. maxiops is SSD powered disk, other
  #   allowed value is "hdd"
  # @param title Name of the disk
  # @param zone Where the disk will reside. Needs to be within same zone
  #   with the server
  #
  # @return HTTParty response object.
  def clone_storage(storage_uuid, zone: "fi-hel1", title:, tier: "maxiops")
    data = {
      "storage" => {
        "zone" => zone,
        "title" => title,
        "tier" => tier
      }
    }

    json = JSON.generate data

    response = post "storage/#{storage_uuid}/clone", json

    response
  end

  # Templatizes existing storage.
  #
  # This operation is asynchronous.
  #
  # Calls POST /1.2/storage/_uuid_/templatize.
  #
  # @param storage_uuid UUID of the storage that will be templatized
  # @param title Name of the template storage
  #
  # @return HTTParty response object.
  def templatize_storage(storage_uuid, title:)
    data = {
      "storage" => {
        "title" => title
      }
    }

    json = JSON.generate data

    response = post "storage/#{storage_uuid}/templatize", json

    response
  end

  # Attaches a storage to a server. Server must be stopped before the
  # storage can be attached.
  #
  # Calls POST /1.2/server/_server_uuid_/storage/attach.
  #
  # Valid values for address are: ide[01]:[01] / scsi:0:[0-7] / virtio:[0-7]
  #
  # @param server_uuid UUID of the server where the disk will be attached to.
  # @param storage_uuid UUID of the storage that will be attached.
  # @param type Type of the disk. Valid values are "disk" and "cdrom".
  # @param address Address where the disk will be attached to. Defaults
  #   to next available address.
  #
  # @return HTTParty response object.
  def attach_storage(server_uuid, storage_uuid:, type: "disk", address: nil)
    data = {
      "storage_device" => {
        "type" => type,
        "storage" => storage_uuid
      }
    }
    data["storage_device"]["address"] = address unless address.nil?

    json = JSON.generate data

    response = post "server/#{server_uuid}/storage/attach", json

    response
  end

  # Detaches storage from a server. Server must be stopped before the
  # storage can be detached.
  #
  # Calls POST /1.2/server/_server_uuid_/storage/detach.
  #
  # @param server_uuid UUID of the server from which to detach the storage.
  # @param address Address where the storage that will be detached resides.
  #
  # @return HTTParty response object.
  def detach_storage(server_uuid, address:)
    data = {
      "storage_device" => {
        "address" => address
      }
    }

    json = JSON.generate data

    response = post "server/#{server_uuid}/storage/detach", json

    response
  end

  # Creates backup from a storage.
  #
  # This operation is asynchronous.
  #
  # Calls /1.2/storage/_uuid_/backup
  #
  # @param storage_uuid UUID of the storage to be backed-up
  # @param title Name of the backup
  #
  # @return HTTParty response object.
  def create_backup(storage_uuid, title:)
    data = {
      "storage" => {
        "title" => title
      }
    }

    json = JSON.generate data

    response = post "storage/#{storage_uuid}/backup", json

    response
  end

  # Restores a backup.
  #
  # If the storage is attached to server, the server must first be stopped.
  #
  # Calls /1.2/storage/_backup_uuid_/restore.
  #
  # @param backup_uuid UUID of the backup
  #
  # @return HTTParty response object.
  def restore_backup(backup_uuid)
    response = post "storage/#{backup_uuid}/restore"

    response
  end

  # Adds storage to favorites.
  #
  # Calls POST /1.2/storage/_storage_uuid_/favorite.
  #
  # @param storage_uuid UUID of the storage to be included in favorites
  #
  # @return HTTParty response object.
  def favorite_storage(storage_uuid)
    response = post "storage/#{storage_uuid}/favorite"

    response
  end

  # Removes storage to favorites.
  #
  # Calls POST /1.2/storage/_storage_uuid_/favorite.
  #
  # @param storage_uuid UUID of the storage to be removed from favorites
  #
  # @return HTTParty response object.
  def defavorite_storage(storage_uuid)
    response = delete "storage/#{storage_uuid}/favorite"

    response
  end

  # Deletes a storage.
  #
  # The storage must be in "online" state and it must not be attached to
  # any server.
  # Backups will not be deleted.
  #
  # @param storage_uuid UUID of the storage that will be deleted.
  #
  # @return HTTParty response object.
  def delete_storage(storage_uuid)
    response = delete "storage/#{storage_uuid}"

    response
  end

  # Lists available predefined plans that can be used to create a server.
  #
  # @return Array of plan hashes
  # @example Return values
  #   [
  #    {
  #      "core_number" : 1,
  #      "memory_amount" : 1024,
  #      "name" : "1xCPU-1GB",
  #      "public_traffic_out" : 2048,
  #      "storage_size" : 30,
  #      "storage_tier" : "maxiops"
  #    }
  #   ]
  def plans
    response = get "plan"

    data = JSON.parse response.body
    data["plans"]["plan"]
  end

  # Lists firewall rules of a server.
  #
  # Calls POST /1.2/server/_uuid_/firewall_rule.
  #
  # @param server_uuid [String] UUID of server
  #
  # @return Array of firewall rules
  # @example Return values
  #   [
  #    {
  #      "action": "accept",
  #      "destination_address_end": "",
  #      "destination_address_start": "",
  #      "destination_port_end": "80",
  #      "destination_port_start": "80",
  #      "direction": "in",
  #      "family": "IPv4",
  #      "icmp_type": "",
  #      "position": "1",
  #      "protocol": "",
  #      "source_address_end": "",
  #      "source_address_start": "",
  #      "source_port_end": "",
  #      "source_port_start": ""
  #    }
  #   ]
  def firewall_rules server_uuid
    response = get "server/#{server_uuid}/firewall_rule"

    data = JSON.parse response.body
    data["firewall_rules"]["firewall_rule"]
  end


  # Creates new firewall rule to a server specified by _server_uuid_.
  #
  # Calls POST /1.2/server/_server_uuid_/firewall_rule.
  #
  # _params_ should contain data as documented in Upcloud’s API:
  # https://www.upcloud.com/api/1.2.3/11-firewall/#create-firewall-rule .
  # It should not contain "firewall_rule" wrapper hash, but only the values inside a hash.
  #
  # @example _params_ contents
  #   {
  #    "position": "1",
  #    "direction": "in",
  #    "family": "IPv4",
  #    "protocol": "tcp",
  #    "source_address_start": "192.168.1.1",
  #    "source_address_end": "192.168.1.255",
  #    "source_port_end": "",
  #    "source_port_start": "",
  #    "destination_address_start": "",
  #    "destination_address_end": "",
  #    "destination_port_start": "22",
  #    "destination_port_end": "22",
  #    "icmp_type": "",
  #    "action": "accept"
  #   }
  #
  # @param server_uuid [String] UUID of server
  # @param params [Hash] Parameters for the firewall rule.
  #
  # @return HTTParty response object.
  def create_firewall_rule server_uuid, params
    data = {
      "firewall_rule" => params
    }

    json = JSON.generate data

    response = post "server/#{server_uuid}/firewall_rule", json

    response
  end

  # Removes a firewall rule at position _position_.
  #
  # Calls DELETE /1.2/server/_server_uuid_/firewall_rule/_position_.
  #
  # A position of a rule can be seen with firewall_rules().
  #
  # @param server_uuid [String] UUID of server
  # @param position [Integer] position of the rule in rule list that will be removed
  #
  # @return HTTParty response object.
  def remove_firewall_rule server_uuid, position
    response = delete "server/#{server_uuid}/firewall_rule/#{position}"

    response
  end

  # Lists all tags with UUIDs of servers they are attached to.
  #
  # Calls GET /1.2/tags.
  #
  # @return Array of tag hashes
  # @example Return values
  #   [
  #    {
  #      "description": "Development servers",
  #      "name": "DEV",
  #      "servers": {
  #        "server": [
  #          "0077fa3d-32db-4b09-9f5f-30d9e9afb565"
  #        ]
  #      }
  #    }
  #   ]
  def tags
    response = get "tags"

    data = JSON.parse response.body
    data["tags"]["tag"]
  end

  # Creates new tag.
  #
  # Calls POST /1.2/tag.
  #
  # _params_ should contain following data
  #   name        *required*
  #   description
  #   servers     *required*
  #
  # @example _params_ hash’s contents
  #   {
  #     "name": "DEV", # required
  #     "description": "Development servers",
  #     "servers":  [
  #       "0077fa3d-32db-4b09-9f5f-30d9e9afb565",
  #       ".."
  #     ]
  #   }
  #
  # @example Response body
  #   {
  #     "name": "DEV",
  #     "description": "Development servers",
  #     "servers": {
  #       "server": [
  #         "0077fa3d-32db-4b09-9f5f-30d9e9afb565"
  #       ]
  #     }
  #   }
  #
  # @param server_uuid [String] UUID of server
  # @param params [Hash] Parameters for the firewall rule.
  #
  # @return Tag parameters as Hash or HTTParty response object in case of error.
  def create_tag server_uuid, params
    data = {
      "tag" => params
    }
    temp = data["servers"]
    data["servers"] = { "server" => temp }

    json = JSON.generate data

    response = post "tag", json
    return response unless response.code == 201

    body = JSON.parse response.body
    body["tag"]
  end

  # Modifies existing tag.
  #
  # Calls PUT /1.2/tag/_tag_.
  #
  # @note Attributes are same as with create_tag().
  #
  # @return Tag parameters as Hash or HTTParty response object in case of error.
  def modify_tag tag
    data = {
      "tag" => params
    }
    temp = data["servers"]
    data["servers"] = { "server" => temp }

    json = JSON.generate data

    response = put "tag/#{tag}", json
    return response unless response.code == 200

    body = JSON.parse response.body
    body["tag"]
  end

  # Deletes existing tag.
  #
  # Calls DELETE /1.2/tag/_tag_.
  #
  # @return HTTParty response object.
  def delete_tag tag
    delete "tag/#{tag}"
  end

  # Attaches one or more tags to a server.
  #
  # Calls POST /1.2/server/_uuid_/tag/_tags_.
  #
  # @param server_uuid [String] UUID of the server
  # @param tags [Array, String] Tags that will be attached to the server
  #
  # @return HTTParty response object.
  def add_tag_to_server server_uuid, tags
    tag = (tags.respond_to? :join && tags.join(",") || tags)

    post "server/#{server_uuid}/tag/#{tag}"
  end

  # Removes one or more tags to a server.
  #
  # Calls POST /1.2/server/_uuid_/untag/_tags_.
  #
  # @param server_uuid [String] UUID of the server
  # @param tags [Array, String] Tags that will be removed from the server
  #
  # @return HTTParty response object.
  def remove_tag_from_server server_uuid, tags
    tag = (tags.respond_to? :join && tags.join(",") || tags)

    post "server/#{server_uuid}/untag/#{tag}"
  end

  # Lists all IP addresses visible to user specified in contructor along with
  # their information and UUIDs of the servers they are bound to.
  #
  # Calls GET /1.2/ip_address.
  #
  # @return [Hash] details of IP addresses
  # @example Return hash
  #   [
  #     {
  #       "access": "private",
  #       "address": "10.0.0.0",
  #       "family": "IPv4",
  #       "ptr_record": "",
  #       "server": "0053cd80-5945-4105-9081-11192806a8f7"
  #     }
  #   ]
  def ip_addresses
    response = get "ip_address"
    body = JSON.parse response.body
    body["ip_addresses"]["ip_address"]
  end

  # Gives details of specific IP address.
  #
  # Calls GET /1.2/ip_address/_ip_address_.
  #
  # @param ip_address [String] IP address to get details for.
  #
  # @return [Hash] details of an IP address
  # @example Return hash
  #   {
  #     "access": "public",
  #     "address": "0.0.0.0"
  #     "family": "IPv4",
  #     "part_of_plan": "yes",
  #     "ptr_record": "test.example.com",
  #     "server": "009d64ef-31d1-4684-a26b-c86c955cbf46",
  #   }
  def ip_address_details ip_address
    response = get "ip_address/#{ip_address}"
    body = JSON.parse response.body
    body["ip_address"]
  end

  # Adds new IP address to given server.
  #
  # Calls POST /1.2/ip_address.
  #
  # @note To add a new IP address, the server must be stopped.
  # @note Only public IP addresses can be added. There is always exactly one private IP address per server.
  # @note There is a maximum of five public IP addresses per server.
  #
  # @param server_uuid [String] UUID of the server
  # @param family ["IPv4", "IPv6"] Type of the IP address.
  #
  # @see https://www.upcloud.com/api/1.2.3/10-ip-addresses/#assign-ip-address Upcloud’s API
  #
  # @return HTTParty response object.
  def new_ip_address_to_server server_uuid, family: "IPv4"
    data = {
      "ip_address" => {
        "family" => family,
        "server" => server_uuid
      }
    }
    json = JSON.generate data

    post "ip_address", json
  end

  # Changes given IP address’s PTR record.
  #
  # Calls PUT /1.2/ip_address.
  #
  # @note Can only be set to public IP addresses.
  #
  # @return HTTParty response object.
  def change_ip_address_ptr ip_address, ptr_record
    data = {
      "ip_address" => {
        "ptr_record" => ptr_record
      }
    }
    json = JSON.generate data

    put "ip_address/#{ip_address}", json
  end

  # Removes IP address (from a server).
  #
  # Calls DELETE /1.2/_ip_address_.
  #
  # @todo I’m fairly sure the API call is wrong, but this is what their documentation says. Please tell me if you test if this one works.
  #
  # @return HTTParty response object.
  def remove_ip_address ip_address
    delete "#{ip_address}"
  end

  private

  def get(action)
    HTTParty.get "https://api.upcloud.com/1.2/#{action}", basic_auth: @auth
  end

  def post(action, body = "")
    HTTParty.post "https://api.upcloud.com/1.2/#{action}",
                  basic_auth: @auth,
                  body: body,
                  headers: { "Content-Type" => "application/json" }
  end

  def put(action, body = "")
    HTTParty.put "https://api.upcloud.com/1.2/#{action}",
                 basic_auth: @auth,
                 body: body,
                 headers: { "Content-Type" => "application/json" }
  end

  def delete(action)
    HTTParty.delete "https://api.upcloud.com/1.2/#{action}",
                    basic_auth: @auth,
                    headers: { "Content-Type" => "application/json" }
  end
end

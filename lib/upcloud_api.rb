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
  # Returns true in success, false if not.
  def login
    response = get "server"
    response.code == 200
  end

  # Returns available server configurations.
  #
  # Calls GET /1.2/server_size.
  #
  # Returns array of server size hashes:
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
  # Returns available credits in the account as a string.
  def account_information
    response = get "account"
    data = JSON.parse response.body
    data["account"]["credits"]
  end

  # Lists servers associated with the account.
  #
  # Calls GET /1.2/server.
  #
  # Returns array of servers with following values or empty array if no servers found.
  # - zone
  # - core_number
  # - title
  # - hostname
  # - memory_amount
  # - uuid
  # - state
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
  # Returns hash of server details or nil:
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
  # Storage devices should be array of hashes containing following data:
  #
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
  # login_user should be following hash or nil:
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
  # ip_addresses should be an array containing :public, :private and/or :ipv6. It defaults to
  # :all, which means the server will get public IPv4, private IPv4 and public IPv6 addresses.
  #
  # @param other [Hash] Other optional arguments create_server API call takes. See Upcloud’s documentation for possible values.
  #
  # Returns HTTParty response object.
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
  # Calls PUT /1.2/server/_uuid_.
  #
  # @param server_uuid [String] UUID of the server that will be modified.
  # @param params [Hash] Hash of params that will be passed to be changed.
  #
  # Returns HTTParty response object.
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
  # Calls DELETE /1.2/server/_uuid_.
  #
  # Returns HTTParty response object.
  def delete_server(server_uuid)
    response = delete "server/#{server_uuid}"

    response
  end

  # Starts server that is shut down.
  #
  # Calls POST /1.2/server/_uuid_/start.
  #
  # @param server_uuid UUID of the server.
  #
  # Returns HTTParty response object.
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
  # Defaults to :soft.
  # @param timeout Time after server will be hard stopped if it did not
  # close cleanly. Only affects :soft type.
  # @param asynchronous If false, this call will wait until the server
  # has really stopped.
  #
  # Raises Timeout::Error in case server does not shut down in 300
  # seconds in non-asynchronous mode.
  #
  # Returns HTTParty response object if server was removed successfully or request is asynchronous and nil otherwise
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
  # Defaults to :soft.
  # @param timeout Time after server will be hard stopped if it did not
  # close cleanly. Only affects :soft type.
  # @param timeout_action What will happen when timeout happens.
  # :destroy hard stops the server and :ignore stops the operation
  # if timeout happens. Default is :ignore.
  #
  # Returns HTTParty response object.
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
  # Available types:
  # - public
  # - private
  # - normal
  # - backup
  # - cdrom
  # - template
  # - favorite
  #
  # @param type Type of the storages to be returned on nil.
  #
  # Returns array of storages, inside "storage" key in the API or empty array if none found.
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
  # Returns hash of following storage details or nil:
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
  # backup_rule should be hash with following attributes:
  # - interval # allowed values: daily / mon / tue / wed / thu / fri / sat / sun
  # - time # allowed values: 0000-2359
  # - retention # How many days backup will be kept. Allowed values: 1-1095
  #
  # @param size Size of the storage in gigabytes
  # @param tier Type of the disk. maxiops is SSD powered disk, other
  # allowed value is "hdd"
  # @param title Name of the disk
  # @param zone Where the disk will reside. Needs to be within same zone
  # with the server
  # @param backup_rule Hash of backup information. If not given, no
  # backups will be automatically created.
  #
  # Returns HTTParty response object.
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
  # backup_rule should be hash with following attributes:
  # - interval # allowed values: daily / mon / tue / wed / thu / fri / sat / sun
  # - time # allowed values: 0000-2359
  # - retention # How many days backup will be kept. Allowed values: 1-1095
  #
  # @param storage_uuid UUID of the storage that will be modified
  # @param size Size of the storage in gigabytes
  # @param title Name of the disk
  # @param backup_rule Hash of backup information. If not given, no
  # backups will be automatically created.
  #
  # Returns HTTParty response object.
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
  # allowed value is "hdd"
  # @param title Name of the disk
  # @param zone Where the disk will reside. Needs to be within same zone
  # with the server
  #
  # Returns HTTParty response object.
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
  # Returns HTTParty response object.
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
  # to next available address.
  #
  # Returns HTTParty response object.
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
  # Returns HTTParty response object.
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
  # Returns HTTParty response object.
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
  # Returns HTTParty response object.
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
  # Returns HTTParty response object.
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
  # Returns HTTParty response object.
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
  # Returns HTTParty response object.
  def delete_storage(storage_uuid)
    response = delete "storage/#{storage_uuid}"

    response
  end

  # Lists available predefined plans that can be used to create a server.
  #
  # Returns Array of plan hashes:
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

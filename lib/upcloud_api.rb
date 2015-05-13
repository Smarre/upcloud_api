
require "timeout"

require "httparty"

class UpcloudApi

    # @param user [String] Upcloud API account
    # @param password [String] Upcloud API password
    def initialize user, password
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
    # Returns true in success, false if not
    def login
        response = get "server"
        response.code == 200
    end

    # Returns available credits.
    #
    # Calls GET /1.2/acccount
    def account_information
        response = get "account"
        data = JSON.parse response.body
        data["acccount"]["credits"]
    end

    # Lists servers associated with the account
    #
    # Calls GET /1.2/server
    #
    # Returns array of servers with values
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
    # Calls GET /1.2/server/#{uuid}
    #
    # @param uuid from UpcloudApi#servers
    def server_details uuid
        response = get "server/#{uuid}"
        data = JSON.parse response.body
        data
    end

    # Lists templates available from Upcloud
    #
    # Calls GET /1.2/storage/template
    def templates
        response = get "storage/template"
        data = JSON.parse response.body
        data
    end

    # Creates new server from template.
    #
    # Calls POST /1.2/server
    #
    # Storage devices should be array of hashes containing following data:
    #
    #   {
    #   "action" => "clone" # Can be "create", "clone" or "attach"
    #   "storage" => template_uuid, # Should be passed only for "clone" or "attach"
    #   "title" => disk_name # Name of the storage,
    #   "tier" => "maxiops" # No sense using HDD any more
    #   }
    #
    # Returns HTTParty response
    def create_server zone: "fi-hel1", title:, hostname:, core_number: 1, memory_amount: 1024, storage_devices:
        data = {
            "server" => {
                "zone" => zone,
                "title" => title,
                "hostname" => hostname,
                "core_number" => core_number,
                "memory_amount" => memory_amount,
                "storage_devices" => { "storage_device" => storage_devices }
            }
        }

        json = JSON.generate data
        response = post "server", json

        response
    end

    # Modifies existing server.
    #
    # In order to modify a server, the server must be stopped first.
    #
    # Calls PUT /1.2/server/#{uuid}
    #
    # @param server_uuid [String] UUID of the server that will be modified.
    # @param params [Hash] Hash of params that will be passed to be changed.
    def modify_server server_uuid, params
        data = { "server" => params }
        json = JSON.generate data
        response = put "server/#{server_uuid}", json

        response
    end

    # Deletes a server.
    #
    # In order to delete a server, the server must be stopped first.
    #
    # Calls DELETE /1.2/server/#{uuid}
    def delete_server server_uuid
        response = delete "server/#{server_uuid}"

        response
    end

    # Starts server that is shut down.
    #
    # Calls POST /1.2/server/#{uuid}/start
    #
    # @param server_uuid UUID of the server
    def start_server server_uuid
        response = post "server/#{server_uuid}/start"

        response
    end

    # Shuts down a server that is currently running
    #
    # Calls POST /1.2/server/#{uuid}/stop
    #
    # Hard shutdown means practically same as taking the power cable off from the computer.
    # Soft shutdown sends ACPI signal to the server, which should then automatically handle shutdown routines by itself.
    # If timeout is given, server will be forcibly shut down after the timeout has expired.
    #
    # @param server_uuid UUID of the server
    # @param type Type of the shutdown. Available types are :hard and :soft. Defaults to :soft.
    # @param timeout Time after server will be hard stopped if it didn’t close cleanly. Only affects :soft type.
    # @param asynchronous If false, this call will wait until the server has really stopped.
    #
    # Raises Timeout::Error in case server does not shut down in 300 seconds in non-asynchronous mode.
    def stop_server server_uuid, type: :soft, timeout: nil, asynchronous: false
        data = {
            "stop_server" => {
                "stop_type" => type.to_s
            }
        }
        data["stop_server"]["timeout"] = timeout unless timeout.nil?

        json = JSON.generate data

        response = post "server/#{server_uuid}/stop", json

        return response if asynchronous

        Timeout::timeout 300 do
            loop do
                details = server_details server_uuid
                return response if details["server"]["state"] == "stopped"
            end
        end
    end

    # Restarts down a server that is currently running
    #
    # Calls POST /1.2/server/#{uuid}/restart
    #
    # Hard shutdown means practically same as taking the power cable off from the computer.
    # Soft shutdown sends ACPI signal to the server, which should then automatically handle shutdown routines by itself.
    # If timeout is given, server will be forcibly shut down after the timeout has expired.
    #
    # @param server_uuid UUID of the server
    # @param type Type of the shutdown. Available types are :hard and :soft. Defaults to :soft.
    # @param timeout Time after server will be hard stopped if it didn’t close cleanly. Only affects :soft type.
    # @param timeout_action What will happen when timeout happens. :destroy hard stops the server and :ignore makes
    # server if timeout happens. Default is :ignore.
    def restart_server server_uuid, type: :soft, timeout: nil, timeout_action: :ignore
        data = {
            "stop_server" => {
                "stop_type" => type.to_s
            }
        }
        data["stop_server"]["timeout"] = timeout unless timeout.nil?

        json = JSON.generate data

        response = post "server/#{server_uuid}/restart", json

        response
    end

    # Lists all storages or storages matching to given type.
    #
    # Calls GET /1.2/storage or /1.2/storage/#{type}
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
    # @param type Type of the storages to be returned on nil
    def storages type: nil
        response = get(type && "storage/#{type}" || "storage")
        data = JSON.parse response.body
        data
    end

    # Shows detailed information of single storage.
    #
    # Calls GET /1.2/storage/#{uuid}
    #
    # @param storage_uuid UUID of the storage
    def storage_details storage_uuid
        response = get "storage/#{storage_uuid}"
        data = JSON.parse response.body
        data
    end

    # Creates new storage.
    #
    # Calls POST /1.2/storage
    #
    # backup_rule should be hash with following attributes:
    # - interval # allowed values: daily / mon / tue / wed / thu / fri / sat / sun
    # - time # allowed values: 0000-2359
    # - retention # How many days backup will be kept. Allowed values: 1-1095
    #
    # @param size Size of the storage in gigabytes
    # @param tier Type of the disk. maxiops is SSD powered disk, other allowed value is "hdd"
    # @param title Name of the disk
    # @param zone Where the disk will reside. Needs to be within same zone with the server
    # @param backup_rule Hash of backup information. If not given, no backups will be automatically created.
    def create_storage size:, tier: "maxiops", title:, zone: "fi-hel1", backup_rule: nil
        data = {
            "storage" => {
                "size" => size,
                "tier" => tier,
                "title" => title,
                "zone" => zone,
                "backup_rule" => backup_rule
            }
        }

        json = JSON.generate data

        response = post "storage", json

        response
    end

    # Modifies existing storage.
    #
    # Calls PUT /1.2/storage/#{uuid}
    #
    # backup_rule should be hash with following attributes:
    # - interval # allowed values: daily / mon / tue / wed / thu / fri / sat / sun
    # - time # allowed values: 0000-2359
    # - retention # How many days backup will be kept. Allowed values: 1-1095
    #
    # @param storage_uuid UUID of the storage that will be modified
    # @param size Size of the storage in gigabytes
    # @param title Name of the disk
    # @param backup_rule Hash of backup information. If not given, no backups will be automatically created.
    def modify_storage storage_uuid, size:, title:, backup_rule: nil
        data = {
            "storage" => {
                "size" => size,
                "title" => title,
                "backup_rule" => backup_rule
            }
        }

        json = JSON.generate data

        response = put "storage/#{storage_uuid}", json

        response
    end

    # Clones existing storage.
    #
    # This operation is asynchronous.
    #
    # Calls POST /1.2/storage/#{uuid}/clone
    #
    # backup_rule should be hash with following attributes:
    # - interval # allowed values: daily / mon / tue / wed / thu / fri / sat / sun
    # - time # allowed values: 0000-2359
    # - retention # How many days backup will be kept. Allowed values: 1-1095
    #
    # @param storage_uuid UUID of the storage that will be modified
    # @param tier Type of the disk. maxiops is SSD powered disk, other allowed value is "hdd"
    # @param title Name of the disk
    # @param zone Where the disk will reside. Needs to be within same zone with the server
    def clone_storage storage_uuid, zone: "fi-hel1", title:, tier: "maxiops"
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

    # Attaches a storage to a server. Server must be stopped before the storage can be attached.
    #
    # Calls POST /1.2/server/#{server_uuid}/storage/attach
    #
    # Valid values for address are: ide[01]:[01] / scsi:0:[0-7] / virtio:[0-7]
    #
    # @param type Type of the disk. Valid values are "disk" and "cdrom".
    # @param address Address where the disk will be attached to. Defaults to next available address.
    # @param server_uuid UUID of the server where the disk will be attached to.
    # @param storage_uuid UUID of the storage that will be attached.
    def attach_storage type: "disk", address: nil, server_uuid:, storage_uuid:
        data = {
            "storage_device" => {
                "type" => type,
                "address" => address,
                "storage" => storage_uuid
            }
        }

        json = JSON.generate data

        response = post "server/#{server_uuid}/storage/attach", json

        response
    end

    # Detaches storage from a server.  Server must be stopped before the storage can be detached.
    #
    # Calls POST /1.2/server/#{server_uuid}/storage/detach
    #
    # @param address Address where the storage that will be detached resides.
    def detach_storage address
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
    # Calls /1.2/storage/#{uuid}/backup
    #
    # @param storage_uuid UUID of the storage to be cloned
    # @param title Name of the backup
    def create_backup storage_uuid, title:
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
    # Calls /1.2/storage/#{uuid}/restore.
    #
    # @param storage_uuid TODO: is this supposed to be UUID of the storage or the backup?
    def create_backup storage_uuid
        response = post "storage/#{storage_uuid}/restore"

        response
    end

    # Deletes a storage.
    #
    # The storage must be in "online" state and it must not be attached to any server.
    # Backups will not be deleted.
    #
    # @param storage_uuid UUID of the storage that will be deleted.
    def delete_storage storage_uuid
        response = delete "storage/#{storage_uuid}"

        response
    end

    private

    def get action
        HTTParty.get "https://api.upcloud.com/1.2/#{action}", basic_auth: @auth
    end

    def post action, body = ""
        HTTParty.post "https://api.upcloud.com/1.2/#{action}", basic_auth: @auth, body: body, headers: { "Content-Type" => "application/json" }
    end

    def put action, body = ""
        HTTParty.put "https://api.upcloud.com/1.2/#{action}", basic_auth: @auth, body: body, headers: { "Content-Type" => "application/json" }
    end

    def delete action, body = ""
        HTTParty.delete "https://api.upcloud.com/1.2/#{action}", basic_auth: @auth, headers: { "Content-Type" => "application/json" }
    end
end

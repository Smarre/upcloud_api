
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
    #   "title" => disk_name # Name of the storage
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
                "storage_devices" => storage_devices
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
    def start_server server_uuid, type: :soft, timeout: nil
        data = {
            "stop_server" => {
                "stop_type" => type.to_s
            }
        }
        data["stop_server"]["timeout"] = timeout unless timeout.nil?

        json = JSON.generate data

        response = post "server/#{server_uuid}/stop", json

        response
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
    def start_server server_uuid, type: :soft, timeout: nil, timeout_action: :ignore
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

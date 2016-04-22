# -*- coding: utf-8 -*-
# Copyright (c) 2016 Qentinel Group
#
# Unit tests for UpCloud API
#
# Please note that not all tests are independent so the whole
# suite is recommended to be run as a whole. Should take around
# 20 minutes. Restoring a backup storage is the most time consuming
# test.
# !!!RUNNING THE SUITE CONSUMES YOUR UpCloud CREDITS!!!
#
# License: see README.md

require 'upcloud_api'
require 'timeout'

def find_server(api, server_uuid)
  servers = api.servers()
  server_found = false
  servers.each do |s|
    if s['uuid'] == server_uuid
      server_found = true
      break
    end
  end
  server_found
end

def server_property(api, server_uuid, property)
  details = api.server_details(server_uuid)
  details['server'][property]
end

def get_storage(api, server_uuid)
  storages = server_property(api, server_uuid, 'storage_devices')
  storages['storage_device'][0]['storage']
end

def storage_exists(api, storage_uuid)
  storages = api.storages()
  storage_found = false
  storages['storages']['storage'].each do |s|
    if s['uuid'] == storage_uuid
      storage_found = true
      break
    end
  end
  storage_found
end

def storage_online(api, storage_uuid, timeout: 100)
  storage_online = false
  begin
    Timeout.timeout timeout do
      loop do
        storage = api.storage_details(storage_uuid)
        if storage['storage']['state'] == 'online'
          storage_online = true
          break
        end
      end
    end
  rescue Timeout::Error
    puts 'Timeout occurred before server was back online'
  end
  storage_online
end

def favorite_storage?(api, storage_uuid)
  storages = api.storages(type: 'favorite')
  is_favorite_storage = false
  storages['storages']['storage'].each do |s|
    if s['uuid'] == storage_uuid
      is_favorite_storage = true
      break
    end
  end
  is_favorite_storage
end

test_server = ''
test_storage = ''
storage_template_id = ''
storage_clone_id = ''
storage_backup_id = ''
detached_storage = ''
begin_credits = 0.0
# Some CD-ROM storage available in UpCloud
test_cdrom = '01000000-0000-4000-8000-000070010101'

describe UpcloudApi do
  context 'when api account exists' do
    upcloud_username = ENV['UPCLOUD_USERNAME']
    upcloud_password = ENV['UPCLOUD_PASSWORD']
    ucapi = UpcloudApi.new(upcloud_username, upcloud_password)
    ucapi_invalid = UpcloudApi.new(upcloud_username, '')
    defaults = {
      title: 'rspec test server',
      hostname: '12345',
      storage_devices: {
        action: 'clone',
        tier: 'maxiops',
        title: 'test disk',
        storage: '015894fe-78fe-4ef2-9794-ec55c733658f'
      }
    }

    before(:all) do
      begin_credits = ucapi.account_information
    end

    after(:all) do
      ucapi.stop_server(test_server, timeout: '30')
      ucapi.delete_storage(storage_backup_id)
      ucapi.delete_storage(storage_template_id)
      ucapi.delete_storage(storage_clone_id)
      ucapi.delete_server(test_server)
      ucapi.delete_storage(test_storage)

      puts 'Credits at the beginning of the tests: ' + begin_credits.to_s
      puts 'Credits after the tests: ' + ucapi.account_information.to_s
      puts 'Credits lost during tests: ' +
           (begin_credits - ucapi.account_information).round(2).to_s
      puts 'PLEASE ENSURE THAT ALL RESERVED CLOUD RESOURCES WERE FREED'
      puts 'SO THAT THEY DO NOT CONSUME YOUR CREDITS'
    end

    it 'should not allow login with empty password' do
      expect(ucapi_invalid.login).to eq(false)
    end

    it 'should allow login with correct username and password' do
      expect(ucapi.login).to eq(true)
    end

    it 'should list at least 10 server configurations available' do
      # Check that there are over 10 configurations available
      expect(ucapi.server_configurations.length).to be > 10
    end

    it 'should report available credits as greater than 1.0' do
      expect(ucapi.account_information).to be > 1.0
    end

    it 'should allow a new test server to be available within 50s' do
      response = ucapi.create_server(defaults)
      test_server = response['server']['uuid']
      begin
        Timeout.timeout 50 do
          sleep 3 while server_property(ucapi, test_server, 'state') ==
                        'maintenance'
        end
      rescue Timeout::Error
        puts 'Timeout occurred before server became available'
      end
      expect(server_property(ucapi, test_server, 'state')).to eq('started')
    end

    it 'should give a non-empty list of servers' do
      expect(ucapi.servers.length).to be > 0
    end

    it 'should give a list of available templates as non-empty Hash' do
      templates = ucapi.templates
      expect(templates).to be_kind_of(Hash)
      expect(templates.length).to be > 0
    end

    it 'should give a list of available storages as non-empty Hash' do
      storages = ucapi.storages
      expect(storages).to be_kind_of(Hash)
      expect(storages.length).to be > 0
    end

    it 'should give a size of a storage as Integer' do
      expect(ucapi.storage_details(get_storage(ucapi, test_server))\
             ['storage']['size']).to be_kind_of(Integer)
    end

    it 'should allow starting the server' do
      expect(server_property(ucapi, test_server, 'state')).to eq('started')
      ucapi.stop_server(test_server, timeout: '30')
      sleep 10
      expect(server_property(ucapi, test_server, 'state')).to eq('stopped')
      ucapi.start_server(test_server)
      sleep 10
      expect(server_property(ucapi, test_server, 'state')).to eq('started')
    end

    it 'should allow restarting the server within 50s' do
      expect(server_property(ucapi, test_server, 'state')).to eq('started')
      ucapi.restart_server(test_server, timeout: '30')
      begin
        Timeout.timeout 50 do
          sleep 3 while server_property(ucapi, test_server, 'state') !=
                        'started'
        end
      rescue Timeout::Error
        puts 'Timeout occurred before server became available after restart'
      end
      expect(server_property(ucapi, test_server, 'state')).to eq('started')
    end

    it 'should allow modifying the server' do
      ucapi.stop_server(test_server, timeout: '30')
      default = {
        core_number: '8',
        memory_amount: '512',
        plan: 'custom'
      }
      ucapi.modify_server(test_server, default)
      expect(server_property(ucapi, test_server, 'memory_amount')).to eq('512')
    end

    it 'should allow attaching a CD-ROM device' do
      ucapi.attach_storage(test_server, storage_uuid: test_cdrom,
                                        type: 'cdrom')
      response = ucapi.server_details(test_server)
      expect(response['server']['storage_devices']\
             ['storage_device'][1]['storage']).to eq(test_cdrom)
    end

    it 'should allow detaching a CD-ROM device' do
      response = ucapi.server_details(test_server)
      address = response['server']['storage_devices']\
                        ['storage_device'][1]['address']
      ucapi.detach_storage(test_server, address: address)
      response = ucapi.server_details(test_server)
      expect(response['server']['storage_devices']\
             ['storage_device'].length).to eq(1)
    end

    it 'should allow creating storages' do
      response = ucapi.create_storage(size: 20, title: 'rpec test disk')
      test_storage = response['storage']['uuid']
      expect(storage_exists(ucapi, test_storage)).to eq(true)
    end

    it 'should allow modifying storages' do
      ucapi.modify_storage(test_storage, size: 25, title: 'rpec test disk 2')
      details = ucapi.storage_details(test_storage)['storage']
      expect(details['size']).to eq(25)
      expect(details['title']).to eq('rpec test disk 2')
    end

    it 'should allow cloning storages' do
      response = ucapi.clone_storage(test_storage, title: 'cloned test storage')
      storage_clone_id = response['storage']['uuid']
      expect(storage_online(ucapi, storage_clone_id)).to eq(true)
    end

    it 'should allow templatizing storages' do
      response = ucapi\
                 .templatize_storage(test_storage, title: \
                                     'test_storage_template')
      storage_template_id = response['storage']['uuid']
      expect(storage_online(ucapi, storage_template_id)).to eq(true)
    end

    it 'should allow detaching storages' do
      response = ucapi.server_details(test_server)
      detached_storage = response['server']['storage_devices']\
                                 ['storage_device'][0]['storage']
      address = response['server']['storage_devices']\
                        ['storage_device'][0]['address']
      ucapi.detach_storage(test_server, address: address)
      response = ucapi.server_details(test_server)
      expect(response['server']['storage_devices']['storage_device']).to eq([])
    end

    it 'should allow attaching storages' do
      response = ucapi.server_details(test_server)
      expect(response['server']['storage_devices']['storage_device']).to eq([])

      ucapi.attach_storage(test_server, storage_uuid: detached_storage)
      response = ucapi.server_details(test_server)
      expect(response['server']['storage_devices']\
                     ['storage_device'][0]['storage']).to eq(detached_storage)
    end

    it 'should allow creating storage backups' do
      response = ucapi.create_backup(test_storage, title: 'test storage backup')
      storage_backup_id = response['storage']['uuid']
      expect(storage_online(ucapi, storage_backup_id)).to eq(true)
    end

    it 'should allow restoring storage backups' do
      ucapi.restore_backup(storage_backup_id)
      # It takes time to restore the backup -> increase timeout
      expect(storage_online(ucapi, test_storage, timeout: 1200)).to eq(true)
    end

    it 'should allow adding storage to favorites' do
      expect(favorite_storage?(ucapi, storage_clone_id)).to eq(false)
      ucapi.favorite_storage(storage_clone_id)
      expect(favorite_storage?(ucapi, storage_clone_id)).to eq(true)
    end

    it 'should allow removing storage to favorites' do
      expect(favorite_storage?(ucapi, storage_clone_id)).to eq(true)
      ucapi.defavorite_storage(storage_clone_id)
      expect(favorite_storage?(ucapi, storage_clone_id)).to eq(false)
    end

    it 'should allow deleting storages' do
      ucapi.delete_storage(storage_backup_id)
      expect(storage_exists(ucapi, storage_backup_id)).to eq(false)
      ucapi.delete_storage(storage_template_id)
      expect(storage_exists(ucapi, storage_template_id)).to eq(false)
      ucapi.delete_storage(storage_clone_id)
      expect(storage_exists(ucapi, storage_clone_id)).to eq(false)
      ucapi.delete_storage(test_storage)
      expect(storage_exists(ucapi, test_storage)).to eq(false)
    end

    it 'should allow deleting the server and its storage' do
      expect(find_server(ucapi, test_server)).to eq(true)
      test_storage = get_storage(ucapi, test_server)
      ucapi.stop_server(test_server, timeout: '30')
      begin
        Timeout.timeout 50 do
          sleep 3 while server_property(ucapi, test_server, 'state') !=
                        'stopped'
        end
      rescue Timeout::Error
        puts 'Timeout occurred before server stopped'
      end
      ucapi.delete_server(test_server)
      expect(find_server(ucapi, test_server)).to eq(false)
      # Storage needs to be deleted separately
      expect(storage_exists(ucapi, test_storage)).to eq(true)
      ucapi.delete_storage(test_storage)
      expect(storage_exists(ucapi, test_storage)).to eq(false)
    end
  end
end

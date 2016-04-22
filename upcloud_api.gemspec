
require_relative "lib/upcloud_api/version"

Gem::Specification.new do |s|
  s.name        = "upcloud_api"
  s.version     = UpcloudApi::VERSION
  s.date        = Date.today
  s.summary     = "Implementation of Upcloud API for VPS management"
  s.description = "Ruby implementation of Upcloud API, meant for programmable maintenance of virtual private servers in Upcloud’s system."
  s.authors     = ["Samu Voutilainen", "Mika Katara"]
  s.email       = "smar@smar.fi"
  s.files       = Dir.glob("lib/**/*.rb")
  s.homepage    = "https://github.com/Smarre/upcloud_api"
  s.license     = "MIT"
  s.add_runtime_dependency "httparty", "~> 0.13"
end

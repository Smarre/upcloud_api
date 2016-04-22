
require "upcloud_api"

When(/^you try to log in to VPS with user "([^"]*)" and password "([^"]*)"$/) do |user, password|
  result = UpcloudApi.login user, password
  expect(result).to be_truthy
end

Then(/^login should succeed$/) do
  pending # Write code here that turns the phrase above into concrete actions
end

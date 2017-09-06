ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'webmock/minitest'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all
  Rails.configuration.teams.keys.each do |name|
    Team.where(name: name).first_or_create!
  end

  setup do
    WebMock.disable_net_connect!(allow_localhost: true)
    stub_request(:get, /api.trello.com/).to_return(status: 404)
  end
end

class ActionController::TestCase
  include Devise::Test::ControllerHelpers

  setup do
    sign_in User.first
  end
end

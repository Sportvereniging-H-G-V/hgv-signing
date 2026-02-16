# frozen_string_literal: true

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
ENV['TZ'] ||= 'UTC'
require_relative '../config/environment'
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'rspec/rails'
require 'capybara/cuprite'
require 'capybara/rspec'
# Load Ferrum fix after Cuprite loads Ferrum
Rails.root.glob('spec/support/**/*.rb').each { |f| require f }
require 'webmock/rspec'
require 'sidekiq/testing'
require 'signing_form_helper'

Sidekiq::Testing.fake!

WebMock.disable_net_connect!(
  allow_localhost: true
)

require 'simplecov' if ENV['COVERAGE']

Capybara.server = :puma, { Silent: true }
Capybara.disable_animation = true
Capybara.default_max_wait_time = 10

Capybara.register_driver(:headless_cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [1200, 800],
                                     process_timeout: 60,
                                     timeout: 60,
                                     js_errors: true,
                                     pending_connection_errors: false,
                                     browser_options: {
                                       'no-sandbox' => nil,
                                       'disable-dev-shm-usage' => nil,
                                       'disable-gpu' => nil,
                                       'disable-setuid-sandbox' => nil,
                                       'disable-software-rasterizer' => nil,
                                       'headless' => 'new'
                                     })
end

Capybara.register_driver(:headful_cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [1200, 800],
                                     headless: false,
                                     process_timeout: 30,
                                     timeout: 30,
                                     js_errors: true,
                                     browser_options: {
                                       'no-sandbox' => nil,
                                       'disable-dev-shm-usage' => nil,
                                       'disable-gpu' => nil,
                                       'disable-setuid-sandbox' => nil
                                     })
end

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Gebruik transactional fixtures, maar met speciale configuratie voor system tests
  # System tests gebruiken shared connection pool voor betere compatibiliteit
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include Devise::Test::IntegrationHelpers
  config.include SigningFormHelper

  config.before(:each, type: :system) do
    # Set browser path for Cuprite - try multiple common locations
    chrome_path = ENV['CHROME_BIN'] || ENV['BROWSER_PATH'] ||
                  `which chromium chromium-browser chrome 2>/dev/null | head -1`.strip

    if chrome_path.present?
      ENV['BROWSER_PATH'] = chrome_path
      ENV['CHROME_BIN'] = chrome_path
    end

    if ENV['HEADLESS'] == 'false'
      driven_by :headful_cuprite
    else
      driven_by :headless_cuprite
    end
  end

  config.after(:each, type: :system) do
    Capybara.reset_sessions!
  end

  config.before do
    Sidekiq::Worker.clear_all
  end

  config.before do |example|
    Sidekiq::Testing.inline! if example.metadata[:sidekiq] == :inline
  end

  config.after do |example|
    Sidekiq::Testing.fake! if example.metadata[:sidekiq] == :inline
  end

  config.before(multitenant: true) do
    allow(Docuseal).to receive(:multitenant?).and_return(true)
  end
end

ActiveSupport.run_load_hooks(:rails_specs, self)

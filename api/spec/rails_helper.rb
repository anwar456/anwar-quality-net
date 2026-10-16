# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'

require 'spec_helper'
require_relative '../config/environment'
abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'
require 'sidekiq/testing'

Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include ApiHelpers

  config.before(:suite) do
    # Jobs are queued in memory, never executed: specs must not call an LLM or need Redis workers.
    Sidekiq::Testing.fake!
    # Throttling is a separate concern; the login limit (5/min) would otherwise break unrelated specs.
    Rack::Attack.enabled = false
  end

  config.before do
    RequestStore.clear!
    Sidekiq::Worker.clear_all
  end
end

# frozen_string_literal: true

# Settings the app cannot work without in production. Fail at boot, loudly, instead of at the first request.
Rails.application.config.after_initialize do
  next unless Rails.env.production?

  web = ENV['WEB_BASE_URL'].to_s
  api = ENV['APP_BASE_URL'].to_s

  raise 'WEB_BASE_URL is required: it is the origin of the web app that hosts /interview/:token' if web.empty?
  raise "WEB_BASE_URL must be an http(s) URL, got #{web.inspect}" unless web.match?(%r{\Ahttps?://[^/\s]+})
  raise 'WEB_BASE_URL and APP_BASE_URL are the same origin: invite links would open the API, not the interview page' if !api.empty? && web.chomp('/') == api.chomp('/')
end

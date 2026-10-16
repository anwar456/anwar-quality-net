# frozen_string_literal: true

require 'rails_helper'

# Protects: the application can start the way production starts it (audit R-31).
# Production sets config.eager_load = true, so every file under app/ must define the constant its path implies.
# Does NOT cover: the rest of config/environments/production.rb - CI boots the app with RAILS_ENV=production for that.
RSpec.describe 'Application boot', :critical do
  it 'can eager load every file, as production does' do
    expect { Rails.application.eager_load! }.not_to raise_error
  end
end

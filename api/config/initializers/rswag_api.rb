# frozen_string_literal: true

# OpenAPI document served at /api-docs/v1/swagger.yaml (development/test only).
if defined?(Rswag::Api)
  Rswag::Api.configure do |c|
    c.openapi_root = Rails.root.join('swagger').to_s
  end
end

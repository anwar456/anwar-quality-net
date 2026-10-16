# frozen_string_literal: true

# Swagger UI served at /api-docs (development/test only).
if defined?(Rswag::Ui)
  Rswag::Ui.configure do |c|
    c.swagger_endpoint '/api-docs/v1/swagger.yaml', 'API V1'
  end
end

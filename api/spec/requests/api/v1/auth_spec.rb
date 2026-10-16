# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Auth & utility endpoints' do
  path '/api/v1/auth/login' do
    post 'Log in an assessor' do
      tags 'Auth'
      description 'Returns a JWT. The tenant (`scheme` claim) is taken from the `X-Tenant-Scheme` header, ' \
                  'otherwise from the first organization (audit R-02: client-controlled, not checked against the user).'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :credentials, in: :body, required: true, schema: {
        type: :object, required: %w[email password],
        properties: { email: { type: :string }, password: { type: :string } }
      }

      let!(:org) { create_org }
      let!(:user) { create_user(email: 'admin@example.test', password: 'Passw0rd!', org: org) }

      response '200', 'token issued' do
        schema type: :object, required: %w[token user],
               properties: {
                 token: { type: :string },
                 user: { type: :object, required: %w[id email role],
                         properties: { id: { type: :integer }, email: { type: :string }, role: { type: :string } } }
               }
        let(:credentials) { { email: 'admin@example.test', password: 'Passw0rd!' } }

        run_test! do
          claims = JsonWebToken.decode(json['token'])
          expect(claims[:role]).to eq('admin')
          expect(claims[:scheme]).to eq(org.scheme)
        end
      end

      response '401', 'wrong password' do
        schema '$ref' => '#/components/schemas/Error'
        let(:credentials) { { email: 'admin@example.test', password: 'nope' } }
        run_test!
      end

      response '403', 'the user is not assigned to an organization' do
        schema '$ref' => '#/components/schemas/Error'
        let!(:unassigned) { create_user(email: 'nobody@example.test', password: 'Passw0rd!', org: nil) }
        let(:credentials) { { email: 'nobody@example.test', password: 'Passw0rd!' } }
        run_test!
      end

      response '401', 'non-admin users cannot log in' do
        schema '$ref' => '#/components/schemas/Error'
        let!(:plain_user) { create_user(email: 'user@example.test', password: 'Passw0rd!', role: 'user', org: org) }
        let(:credentials) { { email: 'user@example.test', password: 'Passw0rd!' } }
        run_test!
      end
    end
  end

  path '/api/v1/health' do
    get 'Liveness check' do
      tags 'Utility'
      produces 'application/json'

      response '200', 'ok' do
        schema type: :object, required: %w[status], properties: { status: { type: :string, example: 'ok' } }
        run_test!
      end
    end
  end

  path '/api/v1/speed_test' do
    post 'Upload speed-test sink' do
      tags 'Utility'
      description 'Accepts any payload, discards it and returns the number of bytes received (used by the candidate hardware check).'
      consumes 'application/octet-stream'
      produces 'application/json'
      parameter name: :payload, in: :body, required: true, schema: { type: :string, format: :binary }

      response '200', 'bytes received' do
        schema type: :object, required: %w[received_bytes], properties: { received_bytes: { type: :integer } }
        let(:payload) { 'x' * 128 }
        run_test! { expect(json['received_bytes']).to eq(128) }
      end
    end
  end
end

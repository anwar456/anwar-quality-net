# frozen_string_literal: true

require 'rails_helper'
require 'rake'

# Protects: a fresh installation can get its first assessor without console surgery (audit R-13).
# Does NOT cover: password policy beyond a minimum length, or rotating an existing password safely.
RSpec.describe 'rake users:create_admin', :critical, type: :request do
  let!(:org) { create_org(scheme: 'org-a') }

  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?('users:create_admin') }

  def run_task(env)
    saved = ENV.to_h.slice('EMAIL', 'PASSWORD', 'SCHEME')
    %w[EMAIL PASSWORD SCHEME].each { |k| ENV.delete(k) }
    env.each { |k, v| ENV[k] = v }
    task = Rake::Task['users:create_admin']
    task.reenable
    task.invoke
  ensure
    %w[EMAIL PASSWORD SCHEME].each { |k| ENV.delete(k) }
    saved.each { |k, v| ENV[k] = v }
  end

  it 'creates an admin bound to the organization, who can then log in' do
    expect { run_task('EMAIL' => 'First.Admin@Example.test', 'PASSWORD' => 'a-long-enough-pass', 'SCHEME' => 'org-a') }
      .to output(/is ready in organization org-a/).to_stdout

    user = User.find_by(email: 'first.admin@example.test')
    expect(user).to have_attributes(role: 'admin', tenant_id: org.id)

    post '/api/v1/auth/login', params: { email: 'first.admin@example.test', password: 'a-long-enough-pass' }.to_json,
                               headers: { 'Content-Type' => 'application/json' }
    expect(response).to have_http_status(:ok)
    expect(token_scheme(json['token'])).to eq('org-a')
  end

  it 'is safe to run twice: it updates the same user' do
    expect do
      2.times { run_task('EMAIL' => 'a@example.test', 'PASSWORD' => 'a-long-enough-pass', 'SCHEME' => 'org-a') }
    end.to output(/is ready/).to_stdout
    expect(User.where(email: 'a@example.test').count).to eq(1)
  end

  it 'refuses an unknown organization, a short password and missing input, creating nothing' do
    [
      { 'EMAIL' => 'x@example.test', 'PASSWORD' => 'a-long-enough-pass', 'SCHEME' => 'nope' },
      { 'EMAIL' => 'x@example.test', 'PASSWORD' => 'short', 'SCHEME' => 'org-a' },
      { 'EMAIL' => 'x@example.test' }
    ].each do |env|
      expect { silence_stderr { run_task(env) } }.to raise_error(SystemExit)
    end
    expect(User.where(email: 'x@example.test')).to be_empty
  end

  def silence_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
  ensure
    $stderr = original
  end
end

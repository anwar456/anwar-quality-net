# frozen_string_literal: true

require 'rails_helper'

# Protects: when an assessor (or any other actor) ends a session, the candidate's live connection follows (audit R-12).
# Before, only the database row changed: the browser kept talking to the interviewer and the model connection kept
# running (and being paid for) until the browser was closed.
# Does NOT cover: real sockets and the real model connection. It drives the middleware's own logic with a fake
# socket; a test through a real WebSocket would be the next step.
RSpec.describe AudioWebsocketMiddleware, :critical do
  # Records what the middleware sends to the browser and whether it closed the connection.
  class FakeSocket
    attr_reader :sent, :closed

    def initialize
      @sent = []
      @closed = false
    end

    def send(message)
      @sent << message
    end

    def close
      @closed = true
    end
  end

  class FakeModelConnection
    attr_reader :closed

    def close
      @closed = true
    end
  end

  let!(:org) { create_org }
  let(:session) { create_interview(create_assessment(org), status: 'active') }
  let(:socket) { FakeSocket.new }
  let(:model) { FakeModelConnection.new }
  let(:middleware) { described_class.new(->(_env) { [200, {}, []] }) }
  let(:state) do
    described_class::ConnectionState.new.tap do |s|
      s.session = session
      s.gemini_client = model
    end
  end

  before do
    # Run what the event loop would schedule, immediately.
    allow(EM).to receive(:schedule) { |&block| block.call }
    allow(EM).to receive(:add_timer) { |_delay, &block| block.call }
  end

  def messages
    socket.sent.map { |m| JSON.parse(m) }
  end

  it 'leaves a running session alone' do
    middleware.send(:check_session_status, socket, state)

    expect(socket.sent).to be_empty
    expect(socket.closed).to be(false)
    expect(model.closed).to be_nil
  end

  it 'tells the browser and closes both connections when the assessor ends the session' do
    state # build the connection while the session is still active
    Session.find(session.id).update!(status: 'ended', end_reason: 'manual_assessor', ended_at: Time.current)

    middleware.send(:check_session_status, socket, state)

    expect(messages).to eq([{ 'type' => 'session_ended', 'reason' => 'manual_assessor' }])
    expect(model.closed).to be(true)
    expect(socket.closed).to be(true)
  end

  it 'says it only once, even if it checks again' do
    Session.find(session.id).update!(status: 'ended', end_reason: 'manual_assessor')

    2.times { middleware.send(:check_session_status, socket, state) }

    expect(messages.size).to eq(1)
  end

  it 'does not announce the end a second time when the middleware ended the session itself' do
    middleware.send(:close_session_after_end, socket, state, reason: 'time_ceiling')
    Session.find(session.id).update!(status: 'ended', end_reason: 'time_ceiling')

    middleware.send(:check_session_status, socket, state)

    expect(messages).to eq([{ 'type' => 'session_ended', 'reason' => 'time_ceiling' }])
  end
end

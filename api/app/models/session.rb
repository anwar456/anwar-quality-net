# frozen_string_literal: true

class Session < ApplicationRecord
  include TenantScoped

  STATUSES   = %w[pending active ended failed].freeze
  END_REASONS = %w[manual_candidate manual_assessor all_covered time_ceiling error].freeze

  belongs_to :assessment
  has_many :transcript_turns, dependent: :destroy
  has_many :coverage_maps, dependent: :destroy
  has_one  :portfolio, dependent: :destroy

  validates :invite_token, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :end_reason, inclusion: { in: END_REASONS }, allow_nil: true

  before_validation :generate_invite_token, on: :create

  scope :active,  -> { where(status: 'active') }
  scope :pending, -> { where(status: 'pending') }
  scope :ended,   -> { where(status: 'ended') }

  def active?  = status == 'active'
  def ended?   = status == 'ended'
  def pending? = status == 'pending'

  # The link a candidate opens. The interview page is served by the web app, not by this API (SPEC-005).
  def invite_url
    "#{web_base_url}/interview/#{invite_token}"
  end

  # True when at least one skill is configured and every configured skill is covered.
  def all_configured_covered?
    configured = coverage_maps.configured
    configured.exists? && !configured.where.not(state: 'covered').exists?
  end

  private

  def web_base_url
    ENV['WEB_BASE_URL'].presence ||
      (Rails.env.production? ? raise(KeyError, 'WEB_BASE_URL is not set') : 'http://localhost:5173')
  end

  def generate_invite_token
    self.invite_token ||= SecureRandom.hex(32)
  end
end

# frozen_string_literal: true

class Portfolio < ApplicationRecord
  GENERATION_STATUSES = %w[pending generating complete failed].freeze

  belongs_to :session
  has_many :portfolio_skills, dependent: :destroy
  has_many :assessor_overrides, through: :portfolio_skills

  validates :generation_status, inclusion: { in: GENERATION_STATUSES }

  # A portfolio has no tenant column of its own: it belongs to a session, and sessions are tenant scoped.
  # Always look portfolios up through this scope in request code. It reads Current.tenant_id explicitly, which
  # raises when no tenant is set, so a missing tenant can never widen access.
  scope :for_current_tenant, -> { where(session_id: Session.where(tenant_id: Current.tenant_id).select(:id)) }

  scope :complete,    -> { where(generation_status: 'complete') }
  scope :failed,      -> { where(generation_status: 'failed') }
  scope :generating,  -> { where(generation_status: 'generating') }

  def complete?    = generation_status == 'complete'
  def generating?  = generation_status == 'generating'
  def failed?      = generation_status == 'failed'
end

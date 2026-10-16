# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  # The organization (tenant) this user acts in. Read-only reference table shared with the main platform.
  belongs_to :organization, foreign_key: :tenant_id, optional: true

  ROLES = %w[admin user].freeze

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }

  before_save :downcase_email

  private

  def downcase_email
    self.email = email.downcase
  end
end

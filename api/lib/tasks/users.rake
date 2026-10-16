# frozen_string_literal: true

namespace :users do
  desc 'Create or update an admin bound to an organization: rails users:create_admin EMAIL=a@b.c PASSWORD=... SCHEME=org-scheme'
  task create_admin: :environment do
    email, password, scheme = ENV.values_at('EMAIL', 'PASSWORD', 'SCHEME').map(&:to_s)

    abort 'EMAIL, PASSWORD and SCHEME are required.' if [email, password, scheme].any?(&:empty?)
    abort 'PASSWORD must be at least 12 characters.' if password.length < 12

    organization = Organization.find_by(scheme: scheme)
    abort "No organization with scheme #{scheme.inspect}. Organizations: #{Organization.pluck(:scheme).join(', ')}" unless organization

    user = User.find_or_initialize_by(email: email.downcase)
    user.assign_attributes(password: password, role: 'admin', tenant_id: organization.id)
    user.save!

    puts "Admin #{user.email} is ready in organization #{organization.scheme}."
  end
end

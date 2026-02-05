# frozen_string_literal: true

namespace :admin do
  desc "Create initial admin user from environment variables (ADMIN_EMAIL, ADMIN_PASSWORD, ADMIN_REGION)"
  task create_initial: :environment do
    AdminUserInitializer.call
  end
end

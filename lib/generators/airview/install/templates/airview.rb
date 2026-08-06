# frozen_string_literal: true

# Airview is intended for trusted internal admin surfaces.
# Protect the mount point in config/routes.rb with your app's authentication.
#
# authenticate :user, ->(user) { user.admin? } do
#   mount Airview::Engine => "/airview"
# end

Airview.configure do |config|
  # Resource configuration is managed through the Airview UI at /airview/setup.
end

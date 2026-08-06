# Airview

Airview is a mountable Rails engine for building an Airtable-like internal admin UI on top of a Rails application's own database.

It lets trusted internal users enable Rails models through the Airview setup UI, then browse records, filter and sort tables, save views, create records, edit cells, delete rows, and work with simple `belongs_to` references.

Airview does not authenticate users. Protect the mounted route in your host Rails app.

## Installation

Add the gem to a Rails 7.1+ application:

```bash
bundle add airview
```

Run the installer and migrate:

```bash
bin/rails generate airview:install
bin/rails db:migrate
```

## Usage

Mount the engine behind your app's authentication:

```ruby
# config/routes.rb
authenticate :user, ->(user) { user.admin? } do
  mount Airview::Engine => "/airview"
end
```

Visit `/airview/setup` to configure resources. Airview discovers concrete host-app ActiveRecord models, pre-fills fields from the schema cache, hides sensitive-looking fields by default, and saves enabled resources in Airview-owned database tables.

Resource configuration is DB-managed. The initializer is reserved for future global settings.

Supported field types:

```ruby
:string, :text, :integer, :float, :decimal, :boolean, :date, :datetime, :select, :belongs_to, :json
```

Only enabled resources and visible fields are shown. Creates, updates, and deletes go through ActiveRecord, so model validations and callbacks still apply.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt.

Run tests and linting:

```bash
bundle exec rake
```

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jacksonriso/airview. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the code of conduct.

## Code of Conduct

Everyone interacting in the Airview project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the code of conduct.

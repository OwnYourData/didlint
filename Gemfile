source "https://rubygems.org"

ruby "3.4.12"

gem "rails", "~> 8.1.0"
gem "puma", "~> 8.0"
gem "rack-cors"
gem "oydid", "~> 0.9.7"
gem "bootsnap", require: false
gem "tzinfo-data"
gem "rswag-api"
gem "rswag-ui"
gem "json-schema"

# UI
gem "sprockets-rails"
gem "sassc-rails"
gem "jquery-rails"
gem "bootstrap-sass", ">= 3.4.1"
gem "font-awesome-rails"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rspec-rails"
  gem "rswag-specs"
end

group :test do
  gem "webmock"
end

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.1.2"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.0.2"

# Use sqlite3 as the database for Active Record
# gem "sqlite3", "~> 1.4"
gem "pg"
gem "puma", "~> 5.0"
gem "rack-cors"
gem "oydid"
gem 'bootsnap'
gem 'tzinfo-data'
gem 'rswag'

# UI
gem 'sass-rails', '~> 5.0'
gem 'uglifier', '>= 1.3.0'
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem "bootstrap-sass", ">= 3.4.1"
gem 'font-awesome-rails'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
end

group :development do
  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
  gem 'derailed'
  gem "stackprof"
  gem "sqlite3"
end


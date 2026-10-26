#!/bin/sh
# exec, so that Puma receives SIGTERM directly and shuts down gracefully
exec bundle exec rails server -b 0.0.0.0

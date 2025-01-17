#!/bin/bash

# Forward all arguments to the appropriate command
if [ "$1" = "bundle" ] || [ "$1" = "bundler" ]; then
    exec bundle "${@:2}"
elif [ "$1" = "ruby" ]; then
    exec ruby "${@:2}"
elif [ "$1" = "irb" ]; then
    exec irb "${@:2}"
elif [ "$1" = "gem" ]; then
    exec gem "${@:2}"
elif [ "$1" = "rubocop" ]; then
    exec bundle exec rubocop "${@:2}"
elif [ "$1" = "rspec" ]; then
    exec bundle exec rspec "${@:2}"
elif [ "$1" = "rails" ]; then
    exec bundle exec rails "${@:2}"
elif [ "$1" = "rake" ]; then
    exec bundle exec rake "${@:2}"
else
    exec "$@"
fi

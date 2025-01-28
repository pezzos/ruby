#!/bin/bash

# Docker Entrypoint Script
# -----------------------
# This script serves as the main entry point for the Ruby development container.
# It routes commands to their appropriate executables while handling bundle context
# and argument passing.

# Usage:
# The script takes the first argument ($1) as the command to execute
# and passes all remaining arguments (${@:2}) to that command.
# Example: When running `docker run ruby-dev rubocop -a`,
# $1 = "rubocop" and ${@:2} = "-a"

# Command Routing Logic:
# 1. Direct execution: Commands that don't need bundle context
# 2. Bundled execution: Commands that require `bundle exec`
# 3. Special cases: Like 'druby' for debugging
# 4. Fallback: Any unrecognized command is executed directly

# Forward all arguments to the appropriate command
if [ "$1" = "bundle" ] || [ "$1" = "bundler" ]; then
    # Direct bundle commands (no need for bundle exec)
    exec bundle "${@:2}"
elif [ "$1" = "ruby" ]; then
    # Direct Ruby interpreter access
    exec ruby "${@:2}"
elif [ "$1" = "irb" ]; then
    # Interactive Ruby console
    exec irb "${@:2}"
elif [ "$1" = "gem" ]; then
    # Gem management commands
    exec gem "${@:2}"
elif [ "$1" = "rubocop" ]; then
    # Ruby static code analyzer (needs bundle exec)
    exec bundle exec rubocop "${@:2}"
elif [ "$1" = "rspec" ]; then
    # Ruby testing framework (needs bundle exec)
    exec bundle exec rspec "${@:2}"
elif [ "$1" = "rails" ]; then
    # Rails framework commands (needs bundle exec)
    exec bundle exec rails "${@:2}"
elif [ "$1" = "rake" ]; then
    # Ruby make tasks (needs bundle exec)
    exec bundle exec rake "${@:2}"
elif [ "$1" = "kitchen" ]; then
    # Test Kitchen for infrastructure testing
    exec bundle exec kitchen "${@:2}"
elif [ "$1" = "druby" ]; then
    # Debug environment with bash shell
    exec bash "${@:2}"
else
    # Fallback: Execute any other command as-is
    exec "$@"
fi

# Note: The use of 'exec' is important as it replaces the current process,
# ensuring proper signal handling and exit code propagation.

# Potential Improvements:
# 1. Add command validation before execution
# 2. Add environment variable checks/setup
# 3. Add logging/debugging options
# 4. Add health checks for required services
# 5. Add configuration file support for command mapping
# 6. Add version checking/compatibility tests
# 7. Add error handling and recovery
# 8. Add support for custom command aliases


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
# 1. Direct execution: Commands that don't need bundle context (bundle, ruby, irb, gem, bash).
# 2. Bundled execution: All other commands are executed via `bundle exec` by default.
# 3. Fallback: If the command is not recognized, execute directly (though the default covers this).

case "$1" in
    bundle|bundler)
        # Direct bundle commands (no need for bundle exec)
        exec bundle "${@:2}"
        ;;
    ruby)
        # Direct Ruby interpreter access
        exec ruby "${@:2}"
        ;;
    irb)
        # Interactive Ruby console
        exec irb "${@:2}"
        ;;
    gem)
        # Gem management commands
        exec gem "${@:2}"
        ;;
    bash|sh)
        # Direct shell access
        exec "$1" "${@:2}"
        ;;
    "")
        # No command provided: Default to an interactive bash shell.
        # echo "Usage: docker run ruby-dev [command] [args...]" >&2
        # echo "Starting interactive bash shell..." >&2
        exec bash
        ;;
    *)
        # Default behavior: Execute the command via `bundle exec`.
        # This ensures the command runs within the context of the project's
        # specific Gemfile dependencies (e.g., rubocop, rspec, rake, kitchen).
        exec bundle exec "$@"
        ;;
esac

# Note: The use of 'exec' is important as it replaces the current process,
# ensuring proper signal handling and exit code propagation.

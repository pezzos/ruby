#!/bin/zsh

# Function to ensure bundle installation
function ensure_bundle_installation() {
    local gemfile_dir
    gemfile_dir=$(find_gemfile "$(pwd)")

    if [[ -n "$gemfile_dir" ]]; then
        # Utiliser un hash du chemin comme identifiant unique
        local dir_hash=$(echo "$gemfile_dir" | md5sum | cut -d' ' -f1)
        local lock_file="/var/lock/ruby-dev/bundle_${dir_hash}.lock"

        if should_bundle_install "$gemfile_dir"; then
            echo "ℹ️ This repo needs bundle install..." >&2
            echo "ℹ️ Running bundle install in $gemfile_dir..." >&2

            # Run a dedicated Docker command to manage the lock and installation
            docker run --rm \
                -v /Users/"$USER"/:/home/"$USER"/ \
                -v bundle_cache31:/usr/local/bundle \
                -v ruby_dev_locks:/var/lock/ruby-dev \
                -e BUNDLE_PATH=/usr/local/bundle \
                -e BUNDLE_APP_CONFIG=/usr/local/bundle \
                --workdir "$(pwd | sed 's/Users/home/')" \
                ruby-dev \
                sh -c "
                    if [ -f $lock_file ]; then
                        echo 'Bundle installation already in progress'
                        exit 0
                    fi
                    trap 'rm -f $lock_file' EXIT
                    echo \$\$ > $lock_file && \
                    cd $(echo "$gemfile_dir" | sed 's/Users/home/') && \
                    bundle clean --force && \
                    bundle install && \
                    bundle update
                "

            # Update the timestamp locally
            date +%s > "$gemfile_dir/.last_bundle_install"
            echo "ℹ️ Bundle install completed" >&2
        fi
    fi
}

# Function to create a temporary file with environment variables
function create_env_file() {
    local tmp_env_file
    tmp_env_file=$(mktemp)
    env > "$tmp_env_file"
    echo "LANG=en_US.UTF-8" >> "$tmp_env_file"
    echo "LC_ALL=en_US.UTF-8" >> "$tmp_env_file"
    echo "$tmp_env_file"
}

# Function to clean up the temporary file
function cleanup_env_file() {
    local env_file="$1"
    rm -f "$env_file"
}

# Helper function to find Gemfile
function find_gemfile() {
    local current_dir
    current_dir="$1"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -f "$current_dir/Gemfile" ]]; then
            echo "$current_dir"
            return 0
        fi
        current_dir="$(dirname "$current_dir")"
    done
    echo ""
    return 1
}

# Helper function to check bundle install timestamp
function should_bundle_install() {
    local gemfile_dir
    gemfile_dir="$1"
    local timestamp_file="$gemfile_dir/.last_bundle_install"

    # If timestamp file doesn't exist, we should bundle install
    if [[ ! -f "$timestamp_file" ]]; then
        return 0
    fi

    # Check if last bundle install was more than 24 hours ago
    current_time=$(date +%s)
    last_install_time=$(cat "$timestamp_file")
    time_diff=$((current_time - last_install_time))

    # 86400 seconds = 24 hours
    if (( time_diff > 86400 )); then
        return 0
    fi

    return 1
}

# Helper function to find rubocop config file in current or parent directories
function find_rubocop_config() {
    local current_dir
    current_dir="$1"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -f "$current_dir/.rubocop.yml" ]]; then
            echo "$current_dir/.rubocop.yml"
            return 0
        fi
        current_dir="$(dirname "$current_dir")"
    done
    echo ""
    return 1
}

# Utility function to get absolute path of a file
function get_absolute_path() {
    echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

# Main Ruby command wrapper
# Runs Ruby commands inside Docker with proper volume mounts and environment
function ruby() {
    ensure_bundle_installation
    local env_file
    env_file=$(create_env_file)
    docker run --rm -i -t \
        --env-file "$env_file" \
        -v /Users/"$USER"/:/home/"$USER"/ \
        -v bundle_cache31:/usr/local/bundle \
        -v ruby_dev_locks:/var/lock/ruby-dev \
        -e BUNDLE_PATH=/usr/local/bundle \
        -e BUNDLE_APP_CONFIG=/usr/local/bundle \
        --workdir "$(pwd | sed 's/Users/home/')" \
        -e PWD="$(pwd | sed 's/Users/home/')" \
        ruby-dev ruby "$@"
    cleanup_env_file "$env_file"
}

# Interactive Ruby console wrapper
# Provides IRB with all gems and environment from the current project
function irb() {
    ensure_bundle_installation
    local env_file
    env_file=$(create_env_file)
    docker run --rm -i -t \
        --env-file "$env_file" \
        -v /Users/"$USER"/:/home/"$USER"/ \
        -v bundle_cache31:/usr/local/bundle \
        -v ruby_dev_locks:/var/lock/ruby-dev \
        -e BUNDLE_PATH=/usr/local/bundle \
        -e BUNDLE_APP_CONFIG=/usr/local/bundle \
        --workdir "$(pwd | sed 's/Users/home/')" \
        -e PWD="$(pwd | sed 's/Users/home/')" \
        ruby-dev irb "$@"
    cleanup_env_file "$env_file"
}

# Rails command wrapper
# Executes Rails commands with proper bundle and environment setup
function rails() {
    ensure_bundle_installation
    local env_file
    env_file=$(create_env_file)
    docker run --rm -i -t \
        --env-file "$env_file" \
        -v /Users/"$USER"/:/home/"$USER"/ \
        -v bundle_cache31:/usr/local/bundle \
        -v ruby_dev_locks:/var/lock/ruby-dev \
        -e BUNDLE_PATH=/usr/local/bundle \
        -e BUNDLE_APP_CONFIG=/usr/local/bundle \
        --workdir "$(pwd | sed 's/Users/home/')" \
        -e PWD="$(pwd | sed 's/Users/home/')" \
        ruby-dev rails "$@"
    cleanup_env_file "$env_file"
}

# Rake task runner wrapper
# Executes Rake tasks with proper bundle context
function rake() {
    ensure_bundle_installation
    local env_file
    env_file=$(create_env_file)
    docker run --rm -i -t \
        --env-file "$env_file" \
        -v /Users/"$USER"/:/home/"$USER"/ \
        -v bundle_cache31:/usr/local/bundle \
        -v ruby_dev_locks:/var/lock/ruby-dev \
        -e BUNDLE_PATH=/usr/local/bundle \
        -e BUNDLE_APP_CONFIG=/usr/local/bundle \
        --workdir "$(pwd | sed 's/Users/home/')" \
        -e PWD="$(pwd | sed 's/Users/home/')" \
        ruby-dev rake "$@"
    cleanup_env_file "$env_file"
}

# RSpec test runner wrapper
# Runs tests with proper bundle and environment configuration
function rspec() {
    ensure_bundle_installation
    local env_file
    env_file=$(create_env_file)
    docker run --rm -i -t \
        --env-file "$env_file" \
        -v /Users/"$USER"/:/home/"$USER"/ \
        -v bundle_cache31:/usr/local/bundle \
        -v ruby_dev_locks:/var/lock/ruby-dev \
        -e BUNDLE_PATH=/usr/local/bundle \
        -e BUNDLE_APP_CONFIG=/usr/local/bundle \
        --workdir "$(pwd | sed 's/Users/home/')" \
        -e PWD="$(pwd | sed 's/Users/home/')" \
        ruby-dev rspec "$@"
    cleanup_env_file "$env_file"
}

# Debug Ruby environment wrapper
# Provides a bash shell inside the Ruby container for debugging
function druby() {
    ensure_bundle_installation
    local env_file
    env_file=$(create_env_file)
    docker run --rm -i -t \
        --env-file "$env_file" \
        -v /Users/"$USER"/:/home/"$USER"/ \
        -v bundle_cache31:/usr/local/bundle \
        -v ruby_dev_locks:/var/lock/ruby-dev \
        -e BUNDLE_PATH=/usr/local/bundle \
        -e BUNDLE_APP_CONFIG=/usr/local/bundle \
        --workdir "$(pwd | sed 's/Users/home/')" \
        -e PWD="$(pwd | sed 's/Users/home/')" \
        ruby-dev bash "$@"
    cleanup_env_file "$env_file"
}

# Bundle command wrapper with lock management
# Handles bundle commands with proper lock files to prevent concurrent installations
function bundle() {
    local gemfile_dir
    gemfile_dir=$(find_gemfile "$(pwd)")
    if [[ -n "$gemfile_dir" && ! -f "$gemfile_dir/.bundle_install_in_progress" ]]; then
        ensure_bundle_installation
    fi

    local env_file
    env_file=$(create_env_file)
    unset DOCKER_HOST
    docker run --rm -i -t \
        --env-file "$env_file" \
        -v /Users/"$USER"/:/home/"$USER"/ \
        -v bundle_cache31:/usr/local/bundle \
        -v ruby_dev_locks:/var/lock/ruby-dev \
        --workdir "$(pwd | sed 's/Users/home/')" \
        -e PWD="$(pwd | sed 's/Users/home/')" \
        -e BUNDLE_PATH=/usr/local/bundle \
        -e BUNDLE_APP_CONFIG=/usr/local/bundle \
        ruby-dev bundle "$@"
    cleanup_env_file "$env_file"

    if [[ -n "$gemfile_dir" && "$1" == "install" ]]; then
        rm -f "$gemfile_dir/.bundle_install_in_progress"
    fi
}

# Rubocop wrapper with advanced configuration handling
# Automatically finds and uses the nearest .rubocop.yml configuration
# Supports both direct file paths and directory scanning
function rubocop() {
    ensure_bundle_installation
    local env_file
    env_file=$(create_env_file)
    local args=()
    local files=()
    local config_file=""
    local has_config_arg=false

    if [[ $# -eq 0 ]]; then
        config_file=$(find_rubocop_config "$(pwd)")
        if [[ -n "$config_file" ]]; then
            args+=("-c" "$config_file")
            files+=(".")
        else
            echo "❌ No .rubocop.yml found in current directory or parent directories" >&2
            return 1
        fi
    else
        for arg in "$@"; do
            if [[ "$arg" == "-c" ]]; then
                has_config_arg=true
                config_file="next"
            elif [[ "$config_file" == "next" ]]; then
                config_file=$(get_absolute_path "$arg")
                config_dir=$(dirname "$config_file")
                args+=("-c" "/workspace/$(basename "$config_file")")
            elif [[ -f "$arg" || -d "$arg" ]]; then
                files+=("$arg")
            else
                args+=("$arg")
            fi
        done

        if [[ "$has_config_arg" == "false" ]]; then
            local found_config
            found_config=$(find_rubocop_config "$(pwd)")
            if [[ -n "$found_config" ]]; then
                args+=("-c" "$found_config")
            fi
        fi
    fi

    if [[ ${#files[@]} -eq 0 ]]; then
        files+=(".")
    fi

    if [[ "$has_config_arg" == "true" ]]; then
        docker run --rm -i -t \
            -v "$config_dir":/workspace \
            -v "$(pwd)":/app \
            -v bundle_cache31:/usr/local/bundle \
            -v ruby_dev_locks:/var/lock/ruby-dev \
            -e BUNDLE_PATH=/usr/local/bundle \
            -e BUNDLE_APP_CONFIG=/usr/local/bundle \
            --workdir /app \
            ruby-dev bundle exec rubocop "${args[@]}" "${files[@]}"
    else
        docker run --rm -i -t \
            -v /Users/"$USER"/:/home/"$USER"/ \
            -v bundle_cache31:/usr/local/bundle \
            -v ruby_dev_locks:/var/lock/ruby-dev \
            -e BUNDLE_PATH=/usr/local/bundle \
            -e BUNDLE_APP_CONFIG=/usr/local/bundle \
            --workdir "$(pwd | sed 's/Users/home/')" \
            -e PWD="$(pwd | sed 's/Users/home/')" \
            ruby-dev bundle exec rubocop "${args[@]}" "${files[@]}"
    fi
    cleanup_env_file "$env_file"
}

# Test Kitchen wrapper for Chef development
# Executes Test Kitchen commands with proper Ruby environment
function kitchen() {
    ensure_bundle_installation
    local env_file
    env_file=$(create_env_file)
    docker run --rm -i -t \
        --env-file "$env_file" \
        -v /Users/"$USER"/:/home/"$USER"/ \
        -v bundle_cache31:/usr/local/bundle \
        -v ruby_dev_locks:/var/lock/ruby-dev \
        -e BUNDLE_PATH=/usr/local/bundle \
        -e BUNDLE_APP_CONFIG=/usr/local/bundle \
        --workdir "$(pwd | sed 's/Users/home/')" \
        -e PWD="$(pwd | sed 's/Users/home/')" \
        ruby-dev bundle exec kitchen "$@"
    cleanup_env_file "$env_file"
}

# Gem command wrapper
# Manages Ruby gems in the containerized environment
function gem() {
    ensure_bundle_installation
    local env_file
    env_file=$(create_env_file)
    docker run --rm -i -t \
        --env-file "$env_file" \
        -v /Users/"$USER"/:/home/"$USER"/ \
        -v bundle_cache31:/usr/local/bundle \
        -v ruby_dev_locks:/var/lock/ruby-dev \
        -e BUNDLE_PATH=/usr/local/bundle \
        -e BUNDLE_APP_CONFIG=/usr/local/bundle \
        --workdir "$(pwd | sed 's/Users/home/')" \
        -e PWD="$(pwd | sed 's/Users/home/')" \
        ruby-dev gem "$@"
    cleanup_env_file "$env_file"
}

# AWS SSO login helper for Test Kitchen
# Handles AWS authentication for Test Kitchen operations
function aws-login() {
    aws sso login --profile test-kitchen
}

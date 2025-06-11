#!/bin/zsh

# Function to check if bundle install is needed based on timestamp.
# Returns 0 if install is needed, 1 otherwise.
function _should_bundle_install() {
    local gemfile_dir="$1"
    local timestamp_file="$gemfile_dir/.last_bundle_install"

    # If timestamp file doesn't exist, we should bundle install
    if [[ ! -f "$timestamp_file" ]]; then
        echo "ℹ️ .last_bundle_install not found." >&2
        return 0 # Needs install
    fi

    # Check if last bundle install was more than 24 hours ago (can be changed)
    # TODO: Consider checking Gemfile/Gemfile.lock modification time instead.
    local current_time=$(date +%s)
    local last_install_time=$(cat "$timestamp_file")
    local time_diff=$((current_time - last_install_time))

    # 86400 seconds = 24 hours
    if (( time_diff > 86400 )); then
        echo "ℹ️ Bundle install is older than 24 hours." >&2
        return 0 # Needs install
    fi

    return 1 # Does not need install
}

# Function to run bundle install if needed.
function _run_bundle_install_if_needed() {
    local gemfile_dir
    gemfile_dir=$(find_gemfile "$(pwd)")

    if [[ -n "$gemfile_dir" ]]; then
        if _should_bundle_install "$gemfile_dir"; then
            echo "ℹ️ Running bundle clean and install in $gemfile_dir..." >&2
            # Use the helper to run bundle clean and install inside the container
            _run_in_ruby_dev bundle clean --force
            if [[ $? -ne 0 ]]; then
                echo "❌ bundle clean failed." >&2
                return 1 # Indicate failure
            fi
            _run_in_ruby_dev bundle install
            local install_status=$?
            if [[ $install_status -ne 0 ]]; then
                echo "❌ bundle install failed." >&2
                return 1 # Indicate failure
            else
                # Update the timestamp locally ONLY if install succeeded
                date +%s > "$gemfile_dir/.last_bundle_install"
                echo "✅ Bundle install completed." >&2
            fi
        fi
    fi
    return 0 # Indicate success or no action needed
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

# Internal helper function to run commands in the Ruby container
function _run_in_ruby_dev() {
    local command_to_run="$1"
    shift # Remove the command from the arguments list
    local cmd_status=0

    # Prepare explicit environment variables
    local docker_env_opts=()
    local vars_to_pass=(
        AWS_ACCESS_KEY_ID AWS_DEFAULT_REGION AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SSH_KEY_ID
        CRITEO_USER USER USERNAME LANG LC_ALL
    )

    for var_name in $vars_to_pass; do
        if [[ -n "${(P)var_name:-}" ]]; then
            docker_env_opts+=("-e" "$var_name=${(P)var_name}")
        fi
    done

    # Build the command array step-by-step
    local docker_cmd=("docker" "run" "--rm" "-i" "-t")

    # Add environment variables if the array is not empty
    if [[ ${#docker_env_opts[@]} -gt 0 ]]; then
        docker_cmd+=("${docker_env_opts[@]}")
    fi

    # Add volumes and other options
    docker_cmd+=(\
        "-v" "/Users/$USER/:/home/$USER/" \
        "-v" "bundle_cache31:/usr/local/bundle" \
        "-v" "ruby_dev_locks:/var/lock/ruby-dev" \
        "-e" "BUNDLE_PATH=/usr/local/bundle" \
        "-e" "BUNDLE_APP_CONFIG=/usr/local/bundle" \
        "--workdir" "$(pwd)" \
        "-e" "PWD=$(pwd)" \
    )

    # Add image name and the command to run
    docker_cmd+=("ruby-dev" "$command_to_run" "$@")

    # Execute the command using the array
    "${docker_cmd[@]}"
    cmd_status=$?

    # Check command exit status
    if [[ $cmd_status -ne 0 ]]; then
        echo "❌ Command '$command_to_run $@' failed with status $cmd_status." >&2
    fi
    return $cmd_status
}

# Main Ruby command wrapper
function ruby() {
    _run_bundle_install_if_needed || return 1 # Exit if bundle install fails
    _run_in_ruby_dev ruby "$@"
}

# Interactive Ruby console wrapper
function irb() {
    _run_bundle_install_if_needed || return 1
    _run_in_ruby_dev irb "$@"
}

# Rake task runner wrapper
function rake() {
    _run_bundle_install_if_needed || return 1
    _run_in_ruby_dev rake "$@"
}

# RSpec test runner wrapper
function rspec() {
    _run_bundle_install_if_needed || return 1
    _run_in_ruby_dev rspec "$@"
}

# Bundle command wrapper
# Note: Does not run automatic bundle install beforehand, as it's often used for managing installation itself.
# Consider adding a specific check if `bundle exec ...` is called via this wrapper.
function bundle() {
    # Note: DOCKER_HOST unset is removed, handle externally if needed.
    _run_in_ruby_dev bundle "$@"
    local bundle_status=$?

    # Original lock file cleanup logic - review if this is still needed/correct
    local gemfile_dir=$(find_gemfile "$(pwd)")
    if [[ -n "$gemfile_dir" && "$1" == "install" && $bundle_status -eq 0 ]]; then
         # Assuming .bundle_install_in_progress was created by a concurrent process?
         # This lock logic seems disconnected from the new install flow.
         # Commenting out for now, re-evaluate locking strategy if needed.
         # rm -f "$gemfile_dir/.bundle_install_in_progress"
    fi
    return $bundle_status
}

# Rubocop wrapper
function rubocop() {
    _run_bundle_install_if_needed || return 1
    local args=()
    local files=()
    local config_file=""
    local config_dir=""
    local has_config_arg=false

    # Simplified logic: Rely on bundle exec rubocop finding the config.
    # Handle explicit -c later if needed.
    if [[ $# -eq 0 ]]; then
        files+=(".")
    else
        # Basic argument parsing, assuming files or options
        for arg in "$@"; do
            # A more robust parsing might be needed for complex cases
            if [[ "$arg" == "-c" ]]; then
                 echo "Warning: Explicit -c handling in wrapper is complex and removed for simplification." >&2
                 echo "Ensure your .rubocop.yml is discoverable by RuboCop." >&2
                 # For now, just pass the args through
                 args+=("$arg")
                 # Set flag to skip auto-detection if needed, but not implemented here
            elif [[ -f "$arg" || -d "$arg" ]]; then
                files+=("$arg")
            else
                args+=("$arg")
            fi
        done
    fi

    if [[ ${#files[@]} -eq 0 ]]; then
        files+=(".") # Default to current directory if no files specified
    fi

    # Always use the standard runner now, assuming rubocop finds the config
    _run_in_ruby_dev rubocop "${args[@]}" "${files[@]}"
}

# Test Kitchen wrapper
function kitchen() {
    _run_bundle_install_if_needed || return 1
    _run_in_ruby_dev kitchen "$@"
}

# Gem command wrapper
# Note: Does not run automatic bundle install beforehand.
function gem() {
    _run_in_ruby_dev gem "$@"
}

# AWS SSO login helper for Test Kitchen
function aws-login() {
    aws sso login --profile test-kitchen
    export AWS_PROFILE=test-kitchen
    export $(aws configure export-credentials --profile test-kitchen --format env)
}

# Test Function for Ruby Development Environment
# ---------------------------------------------
# Usage: Run `test-ruby` from within a Ruby project directory.
function test-ruby() {
    # --- Test Helpers (local to this function) ---
    local _pass_count=0
    local _fail_count=0

    _pass() {
        echo "✅ PASS: $1"
        ((_pass_count++))
    }

    _fail() {
        echo "❌ FAIL: $1" >&2
        ((_fail_count++))
    }

    _info() {
        echo "ℹ️ INFO: $1"
    }

    # Check file relative to project root
    _check_file_in_root() {
        local project_root="$1"
        local file_basename="$2"
        local file_path="$project_root/$file_basename"
        if [[ ! -f "$file_path" ]]; then
            _info "Required file '$file_basename' not found in project root '$project_root' for this test."
            return 1
        fi
        return 0
    }

    # --- Test Execution ---
    echo "--- Running Ruby Function Tests ---"
    local _current_dir="$(pwd)"
    # Use existing find_gemfile to locate project root
    local _project_root=$(find_gemfile "$_current_dir")

    if [[ -z "$_project_root" ]]; then
        _fail "Could not find Gemfile in current directory or any parent directory. Run this from within a Ruby project."
        return 1
    fi

    _info "Detected project root: $_project_root"
    _info "Running tests from: $_current_dir (Commands execute with this as workdir)"

    # Basic Prerequisite: Gemfile (already confirmed)
    _pass "Found Gemfile in $_project_root"

    echo "\n--- Testing Core Functions ---"

    # Test: ruby
    _info "Testing 'ruby' function..."
    if ruby -v > /dev/null 2>&1; then
        _pass "'ruby -v' executed successfully."
    else
        _fail "'ruby -v' failed (Exit status: $?)."
    fi

    # Test: irb
    _info "\nTesting 'irb' function..."
    # IRB version check might fail if `irb` gem isn't explicitly in Gemfile (it's often default)
    if irb --version > /dev/null 2>&1; then
        _pass "'irb --version' executed successfully."
    else
        # Try running a simple command instead
        if echo "exit" | irb > /dev/null 2>&1; then
             _pass "'irb' basic execution seems OK (could not check version)."
        else
            _fail "'irb' failed (Exit status: $?). Note: Requires irb functionality."
        fi
    fi

    # Test: bundle
    _info "\nTesting 'bundle' function..."
    if bundle -v > /dev/null 2>&1; then
        _pass "'bundle -v' executed successfully."
    else
        _fail "'bundle -v' failed (Exit status: $?)."
    fi

    # Test: gem
    _info "\nTesting 'gem' function..."
    if gem -v > /dev/null 2>&1; then
        _pass "'gem -v' executed successfully."
    else
        _fail "'gem -v' failed (Exit status: $?)."
    fi

    echo "\n--- Testing Project-Specific Functions ---"

    # Test: rake
    _info "\nTesting 'rake' function..."
    if _check_file_in_root "$_project_root" "Rakefile"; then
        if rake -T > /dev/null 2>&1; then # -T lists tasks, good non-destructive test
            _pass "'rake -T' executed successfully."
        else
            _fail "'rake -T' failed (Exit status: $?). Note: Requires rake gem and valid Rakefile."
        fi
    else
        _fail "Skipping 'rake' test, Rakefile not found in project root."
    fi

    # Test: rspec
    _info "\nTesting 'rspec' function..."
    if rspec --version > /dev/null 2>&1; then
        _pass "'rspec --version' executed successfully."
    else
        _fail "'rspec --version' failed (Exit status: $?). Note: Requires rspec gem in Gemfile."
    fi

    # Test: rubocop
    _info "\nTesting 'rubocop' function..."
    local rubocop_config_found=false
    if _check_file_in_root "$_project_root" ".rubocop.yml"; then
        rubocop_config_found=true
    fi

    if rubocop --version > /dev/null 2>&1; then
        if [[ "$rubocop_config_found" == true ]]; then
             _pass "'rubocop --version' executed successfully (found project .rubocop.yml)."
        else
             _info "'.rubocop.yml' not found in project root. Rubocop may use defaults."
             _pass "'rubocop --version' executed successfully (without project .rubocop.yml)."
        fi
    else
        _fail "'rubocop --version' failed (Exit status: $?). Note: Requires rubocop gem."
    fi

    # Test: kitchen
    _info "\nTesting 'kitchen' function..."
    local kitchen_config_found=false
    if _check_file_in_root "$_project_root" ".kitchen.yml"; then
        kitchen_config_found=true
    fi

    if kitchen --version > /dev/null 2>&1; then
        if [[ "$kitchen_config_found" == true ]]; then
            _pass "'kitchen --version' executed successfully (found project .kitchen.yml)."
        else
             _info "Optional file '.kitchen.yml' not found in project root. Kitchen may use defaults."
            _pass "'kitchen --version' executed successfully (without project .kitchen.yml)."
        fi
    else
        _fail "'kitchen --version' failed (Exit status: $?). Note: Requires test-kitchen gem."
    fi

    # --- Test Summary ---
    echo "\n--- Test Summary ---"
    echo "✅ Passed: $_pass_count"
    echo "❌ Failed: $_fail_count"

    if [[ $_fail_count -gt 0 ]]; then
        return 1 # Return non-zero status if any test failed
    else
        return 0
    fi
}

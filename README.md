# Ruby Development Environment with Docker

This project provides a containerized Ruby development environment that seamlessly integrates with your local machine while maintaining isolation and consistency. It's designed to make Ruby development easier by handling common development tasks in a containerized environment, preventing "works on my machine" issues.

## Key Features

### Containerized Development Environment
- Complete Ruby 3.1 environment with essential development tools
- Automatic bundle management and gem caching
- Basic concurrent installation protection (via status checks)
- Seamless integration with local filesystem
- MacOS path compatibility handled via Docker volume mapping

### Smart Command Wrappers
- Automatic `bundle install` execution when potentially needed (based on last run timestamp).
- Most commands run via `bundle exec` by default for correct gem context.
- Intelligent configuration file detection (e.g., `.rubocop.yml` by RuboCop itself).
- Proper exit code and signal handling.
- Environment variable preservation via temporary files.
- Enhanced error reporting for failed commands.

### Development Tools Support
- Ruby command execution
- Interactive Ruby console (IRB)
- RSpec test runner
- Rubocop with automatic config detection
- Rake task execution
- Test Kitchen for Chef development
- Bundle management
- Gem handling

## Setup Instructions

1. Clone the repository:
```bash
git clone <repository-url>
cd <repository-name>
```

2. Build the Docker image and create the required Docker volumes:
```bash
# Use --progress=plain to see build logs, including cache usage
docker build --progress=plain --build-arg USER=$(whoami) -t ruby-dev .
docker volume create bundle_cache31
docker volume create ruby_dev_locks
```

3. Install the function definitions:
```bash
cp ruby-functions.zsh $HOME/.ruby-functions.zsh
# Check if .ruby-functions.zsh is already sourced in .zshrc
if ! grep -q 'source.*\.ruby-functions\.zsh' "$HOME/.zshrc"; then
  echo "source \"$HOME/.ruby-functions.zsh\"" >> ~/.zshrc
fi
source ~/.zshrc
```

## Usage Examples

### Basic Ruby Commands
```bash
# Run Ruby script
ruby script.rb

# Start interactive console
irb

# Execute gem commands
gem list
```

### Testing and Linting
```bash
# Run RSpec tests
rspec

# Run Rubocop with automatic config detection
rubocop

# Run specific Rubocop checks
rubocop app/models
```

### Bundle Management
```bash
# Install dependencies
bundle install

# Update gems
bundle update

# Execute commands through bundle
bundle exec rake db:migrate
```

### Testing the install itself
```bash
test-ruby
```

## Technical Details

### Volume Management
- `bundle_cache31`: Persists installed gems, cached across builds.
- `ruby_dev_locks`: Persists lock files (currently minimal usage, primarily for `.last_bundle_install` if moved here).
- Local filesystem mounting: Maps your home directory (`/Users/$USER` to `/home/$USER`).

### Bundle Installation Check
- Before running commands like `rspec`, `rubocop`, etc., the wrapper functions check if a `bundle install` might be needed.
- Currently, this check is based on the timestamp of a `.last_bundle_install` file created in the project root after a successful install (older than 24 hours triggers a check).
- If needed, `bundle clean --force` followed by `bundle install` is executed automatically.
- **Note:** This mechanism is simpler than the previous lock system and primarily prevents redundant installs during active development within a 24h window. It doesn't offer robust locking against truly parallel `bundle install` commands run manually.

### Environment Handling
- Preserves most local environment variables by writing them to a temporary file passed to the container (`--env-file`).
- Maintains proper locale settings (UTF-8).
- Path mapping between host and container is handled directly by Docker's volume mounting.

## Troubleshooting

### Common Issues
1. Lock files not clearing:
```bash
docker volume rm ruby_dev_locks
docker volume create ruby_dev_locks
```

2. Bundle cache issues:
```bash
docker volume rm bundle_cache31
docker volume create bundle_cache31
```

3. Permission problems:
```bash
docker build --build-arg USER=$(whoami) -t ruby-dev .
```

## Contributing

Contributions are welcome! Please feel free to submit pull requests with improvements or bug fixes.

## License

This project is licensed under the [MIT License](LICENSE) - see the [LICENSE](LICENSE) file for details.

#### Best Practices

When modifying the entrypoint (`entrypoint.sh`):
- Maintain the use of `exec` for proper signal handling
- Consider bundle context requirements
- Preserve argument passing with `"${@:2}"`
- Add appropriate error handling
- Document new commands and their usage

When modifying the Zsh functions (`ruby-functions.zsh`):
- Prefer using the `_run_in_ruby_dev` helper function.
- Ensure `_run_bundle_install_if_needed` is called where appropriate.
- Handle exit codes properly.

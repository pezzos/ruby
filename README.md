# Ruby Development Environment with Docker

This project provides a containerized Ruby development environment that seamlessly integrates with your local machine while maintaining isolation and consistency. It's designed to make Ruby development easier by handling common development tasks in a containerized environment, preventing "works on my machine" issues.

## Key Features

### Containerized Development Environment
- Complete Ruby 3.1 environment with essential development tools
- Automatic bundle management and gem caching
- Concurrent installation protection with lock files
- Seamless integration with local filesystem
- MacOS path compatibility built-in

### Smart Command Wrappers
- Automatic bundle installation and updates (every 24 hours)
- Intelligent configuration file detection (e.g., .rubocop.yml)
- Proper exit code and signal handling
- Environment variable preservation

### Development Tools Support
- Ruby command execution
- Interactive Ruby console (IRB)
- Rails commands
- RSpec test runner
- Rubocop with automatic config detection
- Rake task execution
- Test Kitchen for Chef development
- Bundle management
- Gem handling

### Recent Improvements
- Added shared lock volume (`ruby_dev_locks`) to prevent concurrent bundle installations
- Improved lock file management across containers
- Better handling of environment variables
- Enhanced error handling and cleanup
- Consistent volume mounting across all commands

## Setup Instructions

1. Clone the repository:
```bash
git clone <repository-url>
cd <repository-name>
```

2. Build the Docker image:
```bash
docker build --build-arg USER=$(whoami) -t ruby-dev .
```

3. Create required Docker volumes:
```bash
docker volume create bundle_cache31
docker volume create ruby_dev_locks
```

4. Install the function definitions:
```bash
echo "source \"$HOME/.ruby-functions.zsh\"" >> ~/.zshrc
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

### Rails Development
```bash
# Create new Rails application
rails new myapp

# Start Rails server
rails server

# Run Rails console
rails console
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

## Technical Details

### Volume Management
- `bundle_cache31`: Persists installed gems
- `ruby_dev_locks`: Manages concurrent operations
- Local filesystem mounting: Maps your home directory

### Lock System
The environment uses a sophisticated locking system to prevent concurrent bundle installations:
- Lock files are stored in a dedicated Docker volume
- Each project gets a unique lock based on its path
- Automatic cleanup ensures no orphaned locks
- Built-in timeout and retry mechanism

### Environment Handling
- Preserves local environment variables
- Maintains proper locale settings
- Handles path translations between host and container

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

This project is licensed under the MIT License - see the LICENSE file for details.

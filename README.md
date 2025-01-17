# Ruby Development Environment with Docker

This project provides a containerized Ruby development environment that seamlessly integrates with your local machine while maintaining isolation and consistency.

## Components

### Dockerfile

The Dockerfile creates a development environment with the following features:

```dockerfile
FROM ruby:3.1                # Base image with Ruby 3.1
```
- Uses the official Ruby image as base
- Creates a non-root user to run commands safely
- Sets up MacOS path compatibility by linking `/home` to `/Users`
- Installs essential development tools (vim, git, etc.)
- Configures the workspace and permissions
- Uses an entrypoint script to handle commands

### Entrypoint Script

The `entrypoint.sh` script acts as a command router:
- Handles common Ruby commands (`ruby`, `irb`, `gem`)
- Automatically prepends `bundle exec` for tools that require it (rubocop, rspec, rails, rake)
- Maintains proper command execution context
- Preserves exit codes and signal handling

```bash
bundle exec rubocop "${@:2}"  # Example: Ensures rubocop runs in bundler context
```

## Setup Instructions
1. Get the repo wherever you want in your computer then go into it

2. Build the Docker image:
```bash
docker build --build-arg USER=$(whoami) -t ruby-dev .
```

3. Move ruby-functions.zsh in your home dir and source it from your `.zshrc`:
```bash
mv ruby-functions.zsh ~/.ruby-functions.zsh
echo "source \"$HOME/.ruby-functions.zsh\"" >> ~/.zshrc
```

4. Source your updated `.zshrc`:
```bash
source ~/.zshrc
```

## Usage

After setup, you can use Ruby tools as if they were installed locally:

```bash
# Get the ruby's version
ruby -v

# Run Ruby scripts
ruby script.rb

# Start interactive Ruby shell
irb

# Run Rails commands
rails server

# Execute RSpec tests
rspec

# Run Rubocop automatically with the .rubocop.yml of the repo, even in subdir
rubocop
```

All commands will:
- Run inside the Docker container
- Have access to your local files
- Maintain bundle isolation
- Share gem cache between runs
- Automatically check and update bundles when needed (refresh every 24h)

## Features

- **Bundle Management**: Automatic checking and installation of gems
- **Path Compatibility**: Seamless integration between host and container paths
- **Cache Persistence**: Shared bundle cache to avoid repeated gem downloads
- **Development Tools**: Common tools pre-installed in the container
- **Security**: Non-root user execution inside container

## Notes

- The environment uses Docker volumes to persist gems between runs, so keep `docker` running
- Bundle installation status is tracked per repository
- Configuration files (`.rubocop.yml`, etc.) are automatically detected
- All commands maintain proper exit codes and signal handling

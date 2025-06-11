# Guidelines for Ruby Development Environment Repository

This repository provides a containerized Ruby development environment. Follow these rules when modifying files in this project.

## Commit messages
- Use the **Conventional Commits** format for every commit. Include a short summary and a detailed body describing why the change is being made.

## Shell scripts
- Run `shellcheck` on `entrypoint.sh` and `ruby-functions.zsh` after any modification.
- When changing `entrypoint.sh`:
  - Keep using `exec` to launch the final command so signals propagate correctly.
  - Preserve argument passing with `"${@:2}"`.
  - Document new commands or options in `README.md`.
- When changing `ruby-functions.zsh`:
  - Use `_run_in_ruby_dev` to run commands in the container.
  - Call `_run_bundle_install_if_needed` when appropriate.
  - Handle exit codes from commands and propagate failures.

## Testing
- After modifying any scripts, run `zsh -n ruby-functions.zsh` and `bash -n entrypoint.sh` to check for syntax errors.
- If Docker is available, run `source ruby-functions.zsh && test-ruby` to verify the helper functions.

## Documentation
- Update `README.md` when adding or changing features.

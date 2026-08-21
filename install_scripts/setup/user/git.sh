#!/usr/bin/env bash

configure_git_defaults() {
  git config --global user.name egigoka
  git config --global user.email egigoka@gmail.com
  git config --global pull.rebase true
  git -C "$CONFIGS_DIR" config core.hooksPath hooks
  git -C "$CONFIGS_DIR" config filter.codex-projects.clean hooks/filter-codex-projects
}

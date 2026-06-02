#!/usr/bin/env bash
# Checks that every plugin with changed files has a bumped version vs the base branch.
# Usage:
#   ./scripts/check-version-bump.sh              # check all plugins
#   ./scripts/check-version-bump.sh writing      # check specific plugin(s)
#
# Environment:
#   BASE_REF  git ref or SHA to compare against (default: origin/main)
#             CI sets this to github.event.pull_request.base.sha

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
BASE_REF="${BASE_REF:-origin/main}"
FAILED=0

# semver: returns 0 (true) if $1 > $2
version_gt() {
  local a="$1" b="$2"
  [ "$a" != "$b" ] && [ "$a" = "$(printf '%s\n%s' "$a" "$b" | sort -V | tail -1)" ]
}

check_plugin() {
  local domain="$1"
  local plugin_dir="$REPO_ROOT/plugins/$domain"
  local claude_json="$plugin_dir/.claude-plugin/plugin.json"
  local codex_json="$plugin_dir/.codex-plugin/plugin.json"
  local plugin_failed=0

  # Skip if no files changed under this plugin
  local changed
  changed=$(git diff --name-only "$BASE_REF" HEAD -- "plugins/$domain/" 2>/dev/null || true)
  if [ -z "$changed" ]; then
    echo "  plugins/$domain: no changes, skipping"
    return 0
  fi

  echo "  plugins/$domain: changes detected"

  # Check for jq
  if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not installed."
    echo "  Install: brew install jq  (macOS) or apt install jq  (Linux)"
    exit 1
  fi

  # Read current (PR) versions
  local pr_claude pr_codex
  pr_claude=$(jq -r .version "$claude_json" 2>/dev/null || echo "")
  pr_codex=$(jq -r .version "$codex_json" 2>/dev/null || echo "")

  if [ -z "$pr_claude" ] || [ -z "$pr_codex" ]; then
    echo "ERROR: plugins/$domain — could not read version from plugin.json files."
    FAILED=1
    return 0
  fi

  # Read base versions; if plugin is new on this branch, skip version check
  local base_claude base_codex
  base_claude=$(git show "$BASE_REF:plugins/$domain/.claude-plugin/plugin.json" 2>/dev/null | jq -r .version 2>/dev/null || echo "")
  base_codex=$(git show "$BASE_REF:plugins/$domain/.codex-plugin/plugin.json" 2>/dev/null | jq -r .version 2>/dev/null || echo "")

  if [ -z "$base_claude" ] && [ -z "$base_codex" ]; then
    echo "  plugins/$domain: new plugin, version check skipped"
    return 0
  fi

  # Check .claude-plugin version bumped
  if [ -n "$base_claude" ] && ! version_gt "$pr_claude" "$base_claude"; then
    echo ""
    echo "ERROR: plugins/$domain — .claude-plugin/plugin.json version was NOT bumped."
    echo "  base=$base_claude  PR=$pr_claude"
    plugin_failed=1
  fi

  # Check .codex-plugin version bumped
  if [ -n "$base_codex" ] && ! version_gt "$pr_codex" "$base_codex"; then
    echo ""
    echo "ERROR: plugins/$domain — .codex-plugin/plugin.json version was NOT bumped."
    echo "  base=$base_codex  PR=$pr_codex"
    plugin_failed=1
  fi

  # Check both files are in sync with each other
  if [ "$pr_claude" != "$pr_codex" ]; then
    echo ""
    echo "ERROR: plugins/$domain — .claude-plugin and .codex-plugin versions are out of sync."
    echo "  .claude-plugin: $pr_claude"
    echo "  .codex-plugin:  $pr_codex"
    plugin_failed=1
  fi

  if [ "$plugin_failed" -eq 1 ]; then
    echo ""
    echo "  To fix: bump the version in both plugin.json files, then commit."
    echo "    plugins/$domain/.claude-plugin/plugin.json"
    echo "    plugins/$domain/.codex-plugin/plugin.json"
    FAILED=1
  else
    echo "  plugins/$domain: version $pr_claude — OK"
  fi
}

discover_plugins() {
  find "$REPO_ROOT/plugins" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort
}

main() {
  cd "$REPO_ROOT"

  local plugins=()
  if [ "$#" -gt 0 ]; then
    plugins=("$@")
  else
    while IFS= read -r d; do plugins+=("$d"); done < <(discover_plugins)
  fi

  echo "Checking version bumps (base: $BASE_REF)"
  echo ""

  for domain in "${plugins[@]}"; do
    check_plugin "$domain"
  done

  echo ""
  if [ "$FAILED" -eq 1 ]; then
    echo "Version check FAILED. Bump the versions listed above before merging."
    exit 1
  else
    echo "Version check passed."
  fi
}

main "$@"

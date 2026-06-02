#!/usr/bin/env bash
# Bumps plugin manifest patch versions by 0.0.1.
# Usage:
#   ./scripts/bump-plugin-versions.sh                 # bump all plugins
#   ./scripts/bump-plugin-versions.sh legal writing   # bump specific plugin(s)
#   ./scripts/bump-plugin-versions.sh --dry-run       # print planned changes

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DRY_RUN=0

usage() {
  sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo-root)
      if [ "$#" -lt 2 ]; then
        echo "ERROR: --repo-root requires a path."
        exit 1
      fi
      REPO_ROOT="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "ERROR: unknown option: $1"
      usage
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed."
  echo "  Install: brew install jq  (macOS) or apt install jq  (Linux)"
  exit 1
fi

bump_patch() {
  local version="$1"

  if [[ ! "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "ERROR: unsupported version '$version'. Expected MAJOR.MINOR.PATCH."
    exit 1
  fi

  printf '%s.%s.%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "$((BASH_REMATCH[3] + 1))"
}

write_version() {
  local json_file="$1"
  local new_version="$2"
  local tmp_file

  tmp_file="$(mktemp)"
  jq --arg version "$new_version" '.version = $version' "$json_file" > "$tmp_file"
  mv "$tmp_file" "$json_file"
}

discover_plugins() {
  find "$REPO_ROOT/plugins" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort
}

bump_plugin() {
  local domain="$1"
  local plugin_dir="$REPO_ROOT/plugins/$domain"
  local claude_json="$plugin_dir/.claude-plugin/plugin.json"
  local codex_json="$plugin_dir/.codex-plugin/plugin.json"

  if [ ! -f "$claude_json" ] || [ ! -f "$codex_json" ]; then
    echo "ERROR: plugins/$domain is missing one or both plugin.json files."
    return 1
  fi

  local claude_version codex_version new_version
  claude_version="$(jq -r .version "$claude_json")"
  codex_version="$(jq -r .version "$codex_json")"

  if [ "$claude_version" != "$codex_version" ]; then
    echo "ERROR: plugins/$domain versions are out of sync."
    echo "  .claude-plugin: $claude_version"
    echo "  .codex-plugin:  $codex_version"
    return 1
  fi

  new_version="$(bump_patch "$claude_version")"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "plugins/$domain: $claude_version -> $new_version"
    return 0
  fi

  write_version "$claude_json" "$new_version"
  write_version "$codex_json" "$new_version"
  echo "plugins/$domain: $claude_version -> $new_version"
}

main() {
  cd "$REPO_ROOT"

  local plugins=()
  if [ "$#" -gt 0 ]; then
    plugins=("$@")
  else
    while IFS= read -r domain; do
      plugins+=("$domain")
    done < <(discover_plugins)
  fi

  if [ "${#plugins[@]}" -eq 0 ]; then
    echo "No plugins found."
    exit 0
  fi

  local failed=0
  for domain in "${plugins[@]}"; do
    if ! bump_plugin "$domain"; then
      failed=1
    fi
  done

  if [ "$failed" -eq 1 ]; then
    exit 1
  fi
}

main "$@"

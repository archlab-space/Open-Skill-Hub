#!/usr/bin/env bash
# Publishes changed skills to clawhub after a merge to main.
# Compares HEAD vs HEAD~1 to detect which skill directories changed.
# Usage:
#   ./scripts/clawhub-publish.sh              # publish all changed skills
#   ./scripts/clawhub-publish.sh x-post-strategist  # publish specific skill(s)
#
# Environment:
#   CLAWHUB_TOKEN  required — clawhub API token
#   DRY_RUN        if set to "1", prints the publish command without running it

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
FAILED=0

# Convert a kebab-case slug to Title Case display name.
# x-post-strategist -> X Post Strategist
slug_to_name() {
  local slug="$1"
  echo "$slug" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1'
}

# Extract the changelog body for a specific version from CHANGELOG.md.
# Prints lines between "## [VERSION]" and the next "## [" heading (exclusive).
extract_changelog() {
  local changelog_file="$1"
  local version="$2"

  if [ ! -f "$changelog_file" ]; then
    echo "No changelog"
    return 0
  fi

  awk -v ver="$version" '
    /^## \[/ { if (found) exit; if (index($0, "["ver"]") > 0) found=1; next }
    found { print }
  ' "$changelog_file" | sed '/^[[:space:]]*$/d' | head -20
}

publish_skill() {
  local skill_path="$1"
  local skill_name
  skill_name="$(basename "$skill_path")"

  # Derive plugin dir: plugins/<domain>/skills/<skill> -> plugins/<domain>
  local plugin_dir
  plugin_dir="$(dirname "$(dirname "$skill_path")")"

  # Skip if no files changed under this skill since last commit
  local changed
  changed=$(git diff --name-only HEAD~1 HEAD -- "$skill_path/" 2>/dev/null || true)
  if [ -z "$changed" ]; then
    echo "  $skill_name: no changes, skipping"
    return 0
  fi

  echo "  $skill_name: changes detected"

  if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not installed."
    echo "  Install: brew install jq  (macOS) or apt install jq  (Linux)"
    exit 1
  fi

  # Read version from parent plugin
  local claude_json="$plugin_dir/.claude-plugin/plugin.json"
  local version
  version=$(jq -r .version "$claude_json" 2>/dev/null || echo "")

  if [ -z "$version" ]; then
    echo "ERROR: $skill_name — could not read version from $claude_json"
    FAILED=1
    return 0
  fi

  local display_name
  display_name="$(slug_to_name "$skill_name")"

  local changelog_file="$skill_path/CHANGELOG.md"
  local changelog
  changelog="$(extract_changelog "$changelog_file" "$version")"

  if [ -z "$changelog" ]; then
    echo "WARNING: $skill_name — no changelog entry found for version $version in $changelog_file"
    changelog="Version $version"
  fi

  echo "  $skill_name: publishing version $version"

  if [ "${DRY_RUN:-}" = "1" ]; then
    echo "  [DRY RUN] clawhub publish $skill_path --slug $skill_name --name \"$display_name\" --version $version --changelog \"$changelog\""
    return 0
  fi

  clawhub publish "$skill_path" \
    --slug "$skill_name" \
    --name "$display_name" \
    --version "$version" \
    --changelog "$changelog"

  echo "  $skill_name: published OK"
}

discover_skills() {
  find "$REPO_ROOT/plugins" -mindepth 3 -maxdepth 3 -type d -path "*/skills/*" | sort
}

main() {
  if [ -z "${CLAWHUB_TOKEN:-}" ]; then
    echo "ERROR: CLAWHUB_TOKEN environment variable is not set."
    echo "  Set it to your clawhub API token, or store it as a GitHub secret."
    exit 1
  fi

  cd "$REPO_ROOT"

  local skills=()
  if [ "$#" -gt 0 ]; then
    for slug in "$@"; do
      local found_path
      found_path=$(find "$REPO_ROOT/plugins" -mindepth 3 -maxdepth 3 -type d -name "$slug" 2>/dev/null | head -1)
      if [ -z "$found_path" ]; then
        echo "ERROR: skill '$slug' not found under plugins/"
        FAILED=1
        continue
      fi
      skills+=("$found_path")
    done
  else
    while IFS= read -r d; do skills+=("$d"); done < <(discover_skills)
  fi

  echo "Publishing changed skills (comparing HEAD vs HEAD~1)"
  echo ""

  for skill_path in "${skills[@]}"; do
    publish_skill "$skill_path"
  done

  echo ""
  if [ "$FAILED" -eq 1 ]; then
    echo "Publish FAILED for one or more skills."
    exit 1
  else
    echo "Publish step complete."
  fi
}

main "$@"

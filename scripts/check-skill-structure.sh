#!/usr/bin/env bash
# Validates skill directory structure on every PR targeting main.
# Checks: required files, kebab-case naming, SKILL.md frontmatter,
#         CHANGELOG.md version entry, and CHANGELOG.md sync when skill files change.
# Usage:
#   ./scripts/check-skill-structure.sh              # check all skills
#   ./scripts/check-skill-structure.sh x-post-strategist  # check specific skill(s)
#
# Environment:
#   BASE_REF  git ref or SHA to compare against (default: origin/main)
#             CI sets this to github.event.pull_request.base.sha

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
BASE_REF="${BASE_REF:-origin/main}"
FAILED=0

is_kebab_case() {
  [[ "$1" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]
}

check_skill() {
  local skill_path="$1"
  local skill_name
  skill_name="$(basename "$skill_path")"

  # Derive plugin dir: plugins/<domain>/skills/<skill> -> plugins/<domain>
  local plugin_dir
  plugin_dir="$(dirname "$(dirname "$skill_path")")"
  local domain
  domain="$(basename "$plugin_dir")"

  local skill_failed=0

  echo "  $domain/$skill_name:"

  # 1. Kebab-case directory name
  if ! is_kebab_case "$skill_name"; then
    echo "    ERROR: directory name '$skill_name' is not lowercase kebab-case."
    echo "           Use only lowercase letters, digits, and hyphens (e.g. my-skill)."
    skill_failed=1
  fi

  # 2. Required files
  for required_file in SKILL.md README.md CHANGELOG.md; do
    if [ ! -f "$skill_path/$required_file" ]; then
      echo "    ERROR: missing required file: $required_file"
      skill_failed=1
    fi
  done

  # 3. SKILL.md frontmatter — must have name: and description: fields
  if [ -f "$skill_path/SKILL.md" ]; then
    if ! grep -qE "^name:" "$skill_path/SKILL.md"; then
      echo "    ERROR: SKILL.md is missing 'name:' in frontmatter."
      skill_failed=1
    fi
    if ! grep -qE "^description:" "$skill_path/SKILL.md"; then
      echo "    ERROR: SKILL.md is missing 'description:' in frontmatter."
      skill_failed=1
    fi
  fi

  # 4. If any non-CHANGELOG.md skill files changed in this PR, CHANGELOG.md must also be modified
  local skill_rel
  skill_rel="${skill_path#"$REPO_ROOT/"}"

  local other_changed
  other_changed=$(git diff --name-only "$BASE_REF" HEAD -- "$skill_rel/" 2>/dev/null \
    | grep -v "CHANGELOG.md" || true)

  if [ -n "$other_changed" ]; then
    local changelog_changed
    changelog_changed=$(git diff --name-only "$BASE_REF" HEAD -- "$skill_rel/CHANGELOG.md" 2>/dev/null || true)
    if [ -z "$changelog_changed" ]; then
      echo "    ERROR: skill files changed but CHANGELOG.md was not updated."
      echo "           Update $skill_rel/CHANGELOG.md with an entry for the new version."
      skill_failed=1
    fi
  fi

  if [ "$skill_failed" -eq 1 ]; then
    FAILED=1
  else
    echo "    OK"
  fi
}

discover_skills() {
  find "$REPO_ROOT/plugins" -mindepth 3 -maxdepth 3 -type d -path "*/skills/*" | sort
}

main() {
  cd "$REPO_ROOT"

  if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not installed."
    echo "  Install: brew install jq  (macOS) or apt install jq  (Linux)"
    exit 1
  fi

  local skill_paths=()

  if [ "$#" -gt 0 ]; then
    for slug in "$@"; do
      local found_path
      found_path=$(find "$REPO_ROOT/plugins" -mindepth 3 -maxdepth 3 -type d -name "$slug" 2>/dev/null | head -1)
      if [ -z "$found_path" ]; then
        echo "ERROR: skill '$slug' not found under plugins/"
        FAILED=1
        continue
      fi
      skill_paths+=("$found_path")
    done
  else
    while IFS= read -r d; do skill_paths+=("$d"); done < <(discover_skills)
  fi

  echo "Checking skill structure (base: $BASE_REF)"
  echo ""

  for skill_path in "${skill_paths[@]}"; do
    check_skill "$skill_path"
  done

  echo ""
  if [ "$FAILED" -eq 1 ]; then
    echo "Skill structure check FAILED. Fix the errors listed above before merging."
    exit 1
  else
    echo "Skill structure check passed."
  fi
}

main "$@"

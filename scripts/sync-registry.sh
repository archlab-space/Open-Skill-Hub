#!/usr/bin/env bash
# Regenerates both marketplace.json files from the plugins/ directory.
# Reads each plugins/<domain>/.claude-plugin/plugin.json for metadata.
# Usage: ./scripts/sync-registry.sh
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
PLUGINS_DIR="$REPO_ROOT/plugins"

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed."
  exit 1
fi

claude_plugins="[]"
codex_plugins="[]"

for plugin_dir in "$PLUGINS_DIR"/*/; do
  [ -d "$plugin_dir" ] || continue
  domain="$(basename "$plugin_dir")"
  claude_json="$plugin_dir.claude-plugin/plugin.json"

  if [ ! -f "$claude_json" ]; then
    echo "WARNING: no .claude-plugin/plugin.json in $plugin_dir, skipping"
    continue
  fi

  name="$(jq -r .name "$claude_json")"
  description="$(jq -r .description "$claude_json")"
  author_name="$(jq -r '.author.name' "$claude_json")"
  author_email="$(jq -r '.author.email' "$claude_json")"

  claude_entry=$(jq -n \
    --arg name "$name" \
    --arg description "$description" \
    --arg source "./plugins/$domain" \
    --arg aname "$author_name" \
    --arg aemail "$author_email" \
    '{name: $name, description: $description, source: $source, author: {name: $aname, email: $aemail}}')

  codex_entry=$(jq -n \
    --arg name "$name" \
    --arg path "./plugins/$domain" \
    '{name: $name, source: {source: "local", path: $path}, policy: {installation: "AVAILABLE", authentication: "ON_INSTALL"}, category: "Productivity"}')

  claude_plugins=$(printf '%s' "$claude_plugins" | jq --argjson e "$claude_entry" '. + [$e]')
  codex_plugins=$(printf '%s' "$codex_plugins" | jq --argjson e "$codex_entry" '. + [$e]')
done

# Write .claude-plugin/marketplace.json
jq -n \
  --arg name "open-skill-hub" \
  --arg description "Personal AI skill library organized into domain-specific plugins" \
  --arg oname "devasher" \
  --arg oemail "hlxstc680@gmail.com" \
  --argjson plugins "$claude_plugins" \
  '{name: $name, description: $description, owner: {name: $oname, email: $oemail}, plugins: $plugins}' \
  > "$REPO_ROOT/.claude-plugin/marketplace.json"

echo "Written .claude-plugin/marketplace.json"

# Write .agents/plugins/marketplace.json
jq -n \
  --arg name "open-skill-hub" \
  --argjson plugins "$codex_plugins" \
  '{name: $name, interface: {displayName: "Open Skill Hub"}, plugins: $plugins}' \
  > "$REPO_ROOT/.agents/plugins/marketplace.json"

echo "Written .agents/plugins/marketplace.json"

# Rebuild ## Skills table in README.md between <!-- skills-start --> and <!-- skills-end -->
README="$REPO_ROOT/README.md"

extract_skill_description() {
  awk '
    BEGIN { in_fm=0; in_desc=0; out=""; printed=0 }
    /^---[[:space:]]*$/ {
      if (!in_fm) { in_fm=1; next }
      if (in_fm) { exit }
    }
    in_fm && in_desc {
      if ($0 ~ /^[[:space:]]+/) {
        line=$0
        sub(/^[[:space:]]+/, "", line)
        out = out (out ? " " : "") line
        next
      }
      if (out != "") { print out; printed=1 }
      exit
    }
    in_fm && /^description:[[:space:]]*/ {
      line=$0
      sub(/^description:[[:space:]]*/, "", line)
      if (line == ">" || line == ">-" || line == "|" || line == "|-") {
        in_desc=1
        next
      }
      gsub(/^["'\'']|["'\'']$/, "", line)
      print line
      printed=1
      exit
    }
    END {
      if (in_desc && out != "" && !printed) print out
    }
  ' "$1"
}

table="| Plugin | Skill | Description |\n|--------|-------|-------------|\n"

while IFS= read -r skill_md; do
  plugin="$(echo "$skill_md" | awk -F/ '{print $(NF-3)}')"
  skill="$(echo "$skill_md" | awk -F/ '{print $(NF-1)}')"
  # Extract description from frontmatter (first --- block)
  desc="$(extract_skill_description "$skill_md")"
  desc="${desc//$'\n'/ }"
  desc="${desc//|/\\|}"
  path="plugins/$plugin/skills/$skill/"
  table="${table}| $plugin | [$skill]($path) | $desc |\n"
done < <(find "$PLUGINS_DIR" -path "*/skills/*/SKILL.md" | sort)

# Replace content between markers (portable: works on macOS and Linux)
awk -v block="$table" '
  /<!-- skills-start -->/ { print; printf "%s", block; skip=1; next }
  /<!-- skills-end -->/   { skip=0 }
  !skip                   { print }
' "$README" > "$README.tmp" && mv "$README.tmp" "$README"

echo "Updated README.md skills table"

#!/usr/bin/env bash
# Usage: ./scripts/add-feedback-prompt.sh <plugin-dir>
# Example: ./scripts/add-feedback-prompt.sh plugins/legal
set -euo pipefail

PLUGIN_DIR="${1:?Usage: $0 <plugin-dir>}"
ISSUES_URL="https://github.com/archlab-space/Open-Skill-Hub/issues"
DATE=$(date +%Y-%m-%d)

README_SECTION=$(cat <<'SECTION'

## Feedback & Contributions

Found a gap or have a suggestion? [Open an issue or PR](ISSUES_URL_PLACEHOLDER) — improvements are welcome.
SECTION
)
README_SECTION="${README_SECTION//ISSUES_URL_PLACEHOLDER/$ISSUES_URL}"

SKILL_SECTION=$(cat <<'SECTION'

## Feedback

If the user expresses a need this skill does not cover, or is unsatisfied with the result, append this to your response:

> "This skill may not fully cover your situation. Suggestions for improvement are welcome — [open an issue or PR](ISSUES_URL_PLACEHOLDER)."

Do not include this message in normal interactions.
SECTION
)
SKILL_SECTION="${SKILL_SECTION//ISSUES_URL_PLACEHOLDER/$ISSUES_URL}"

updated_skills=()

for skill_dir in "$PLUGIN_DIR"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  readme="$skill_dir/README.md"
  skill_md="$skill_dir/SKILL.md"
  changelog="$skill_dir/CHANGELOG.md"

  # Append to README.md
  if [ -f "$readme" ] && ! grep -q "## Feedback & Contributions" "$readme"; then
    printf '%s' "$README_SECTION" >> "$readme"
    echo "  README updated: $readme"
  fi

  # Append to SKILL.md
  if [ -f "$skill_md" ] && ! grep -q "^## Feedback" "$skill_md"; then
    printf '%s' "$SKILL_SECTION" >> "$skill_md"
    echo "  SKILL.md updated: $skill_md"
  fi

  # Bump CHANGELOG
  if [ -f "$changelog" ]; then
    current_version=$(grep -m1 "^## \[" "$changelog" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -1)
    if [ -n "$current_version" ]; then
      IFS='.' read -ra parts <<< "$current_version"
      new_patch=$(( parts[2] + 1 ))
      new_version="${parts[0]}.${parts[1]}.$new_patch"
      new_entry="## [$new_version] - $DATE\n\n### Added\n- Feedback prompt in README.md and conditional feedback section in SKILL.md\n"
      python3 - "$changelog" "$new_entry" <<'PYEOF'
import sys
path, entry = sys.argv[1], sys.argv[2]
content = open(path).read()
idx = content.find('\n## [')
if idx == -1:
    content = content + '\n' + entry.replace('\\n', '\n')
else:
    content = content[:idx+1] + entry.replace('\\n', '\n') + '\n' + content[idx+1:]
open(path, 'w').write(content)
PYEOF
      echo "  CHANGELOG bumped: $changelog ($current_version -> $new_version)"
      updated_skills+=("$skill_name:$new_version")
    fi
  fi
done

# Bump plugin version in both plugin.json files
for json_file in "$PLUGIN_DIR"/.claude-plugin/plugin.json "$PLUGIN_DIR"/.codex-plugin/plugin.json; do
  if [ -f "$json_file" ]; then
    current_version=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d['version'])" "$json_file")
    IFS='.' read -ra parts <<< "$current_version"
    new_patch=$(( parts[2] + 1 ))
    new_version="${parts[0]}.${parts[1]}.$new_patch"
    python3 - "$json_file" "$new_version" <<'PYEOF'
import json, sys
path, new_ver = sys.argv[1], sys.argv[2]
d = json.load(open(path))
d['version'] = new_ver
open(path, 'w').write(json.dumps(d, indent=2) + '\n')
PYEOF
    echo "  plugin.json bumped: $json_file ($current_version -> $new_version)"
  fi
done

echo ""
echo "Done. Skills updated: ${updated_skills[*]:-none}"

#!/usr/bin/env bash
# Regression tests for scripts/bump-plugin-versions.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/bump-plugin-versions.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p \
  "$tmpdir/plugins/alpha/.claude-plugin" \
  "$tmpdir/plugins/alpha/.codex-plugin" \
  "$tmpdir/plugins/beta/.claude-plugin" \
  "$tmpdir/plugins/beta/.codex-plugin"

cat > "$tmpdir/plugins/alpha/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "alpha",
  "version": "0.1.9"
}
JSON

cat > "$tmpdir/plugins/alpha/.codex-plugin/plugin.json" <<'JSON'
{
  "name": "alpha",
  "version": "0.1.9"
}
JSON

cat > "$tmpdir/plugins/beta/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "beta",
  "version": "2.0.0"
}
JSON

cat > "$tmpdir/plugins/beta/.codex-plugin/plugin.json" <<'JSON'
{
  "name": "beta",
  "version": "2.0.0"
}
JSON

"$SCRIPT" --repo-root "$tmpdir" >/dev/null

alpha_claude="$(jq -r .version "$tmpdir/plugins/alpha/.claude-plugin/plugin.json")"
alpha_codex="$(jq -r .version "$tmpdir/plugins/alpha/.codex-plugin/plugin.json")"
beta_claude="$(jq -r .version "$tmpdir/plugins/beta/.claude-plugin/plugin.json")"
beta_codex="$(jq -r .version "$tmpdir/plugins/beta/.codex-plugin/plugin.json")"

if [ "$alpha_claude" != "0.1.10" ] || [ "$alpha_codex" != "0.1.10" ]; then
  echo "alpha was not bumped to 0.1.10"
  exit 1
fi

if [ "$beta_claude" != "2.0.1" ] || [ "$beta_codex" != "2.0.1" ]; then
  echo "beta was not bumped to 2.0.1"
  exit 1
fi

echo "bump-plugin-versions tests passed."

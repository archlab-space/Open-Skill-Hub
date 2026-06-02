# Changelog

## [0.5.7] - 2026-05-29
- Remove hardcoded `obsidian-vault-writer` skill reference in Step 10; now uses generic language to support any installed Obsidian skill.

## [0.5.6] - 2026-05-28
Rewrote frontmatter description to concise 200–500 character format for improved agent-trigger clarity.

## [0.5.5] - 2026-05-28

- Replace Google Sheets output (Step 10) with Obsidian vault writing via `obsidian-vault-writer` skill
- Remove `google-sheet-sync.md` and `scripts/` directory

## [0.5.4] - 2026-05-21

### Added
- Feedback prompt in README.md and conditional feedback section in SKILL.md

## [0.5.3] - 2026-05-20
- Fix `getCredentials()` in `save_to_sheet.js`: load `client_id`/`client_secret` from `credentials.json` before token cache check so token refresh works correctly
- Add `normalizeToken()` to handle Python-client token format (`token` → `access_token`, `expiry` → `expiry_date`) so tokens created by other Google OAuth clients are reused without re-auth

## [0.5.2] - 2026-05-20
- Migrate `scripts/save_to_sheet.py` → `scripts/save_to_sheet.js` (Node.js); identical CLI interface and output; depends only on `googleapis` via `npm install` in the `scripts/` directory; removes Python runtime requirement
- Add `scripts/package.json`; delete `scripts/save_to_sheet.py`
- Update `google-sheet-sync.md` and `SKILL.md` to reference `node` / `npm install` instead of `python` / `pip`

## [0.5.1] - 2026-05-20
- Rewrite `google-sheet-sync.md` with wizard structure: First-time setup (pip install as step 1, OAuth2 promoted to Option A for personal use), Daily use, and Reference sections; add verify command
- Fix `SKILL.md` Step 10 to clarify script path resolution and surface dependency install check before first save

## [0.5.0] - 2026-05-20
- Add Step 10: optional Google Sheets storage with session mode and per-tweet mode
- Add `google-sheet-sync.md`: sheet column structure, deeplink format, auth setup (service account + OAuth2), usage examples
- Add `scripts/save_to_sheet.py`: appends variants as side-by-side columns with `=HYPERLINK()` deeplinks for one-click X publishing; CSV fallback on failure

## [0.4.2] - 2026-05-18
Added Writing Principles section with 7 concrete principles (natural voice, subjective perspective, scene grounding, cut ornate language, no forced profundity, specific beats vague, leave room). Each principle includes before/after examples in English and Chinese. Added Writing Principles row to Step 9 review rubric.

## [0.4.1] - 2026-05-14
Added two-phase workflow: research phase with context enrichment and fact verification, plus voice calibration to preserve the author's writing style.

## [0.3.1] - 2026-05-01
Improved required inputs and smarter defaults for format selection and thread structure.

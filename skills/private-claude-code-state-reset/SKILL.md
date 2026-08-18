---
name: private-claude-code-state-reset
description: Safely reset Claude Code local state on macOS or Windows and migrate it to a fresh user identity. Full backup first (timestamped to the second), then auto-migrate everything (projects memory, sessions, history, skills, agents, plugins, rules, hooks) into the new identity, excluding only old-identity state (credentials, device/telemetry IDs, account fields). Old data is kept as backup until the user confirms, then deleted manually. Use when the user asks to delete/recreate ~/.claude or %USERPROFILE%\.claude, regenerate Claude Code machine code/device identity, switch to a new account while keeping all data, or decide which .claude files are identity vs migratable content.
---

# Private Claude Code State Reset

## Purpose

Reset Claude Code's local identity without losing anything else. The model is:

1. **Backup everything first** (timestamped to the second, verified).
2. **Regenerate a fresh identity** (new login / device state).
3. **Auto-migrate all content by default** — everything migrates except an
   explicit identity/runtime exclusion list (blacklist, not whitelist).
4. **Scan for identity leakage** in the migrated tree.
5. **Keep old data as rollback**. Delete `.claude.old` and backups only after
   the user explicitly confirms the new identity works — that deletion is the
   final removal of the old identity.

Treat this as a high-risk filesystem workflow: inspect first, back up first,
never delete before the user confirms.

## Platform Detection

Detect the platform first, then use the matching command variant throughout:

- **macOS / Linux**: `uname` prints `Darwin`/`Linux`. Use bash/zsh + `rsync`.
- **Windows**: use PowerShell + `robocopy`. In this workspace run PowerShell
  via `rtk proxy pwsh -NoProfile -Command ...`.

Path map (same roles on both platforms):

| Role                    | macOS                        | Windows                              |
| ----------------------- | ---------------------------- | ------------------------------------ |
| Active config           | `~/.claude`                  | `%USERPROFILE%\.claude`              |
| Top-level account config (identity-bearing) | `~/.claude.json` | `%USERPROFILE%\.claude.json`     |
| Local rollback copy     | `~/.claude.old` (+ `~/.claude.json.old`) | `%USERPROFILE%\.claude.old` (+ `.claude.json.old`) |
| Timestamped backups     | `~/claude-backups/.claude-backup-*` | `%USERPROFILE%\Desktop\claude-backups\.claude-backup-*` |

Backup folder names embed a timestamp precise to the second:
`%Y%m%d-%H%M%S` (macOS) / `yyyyMMdd-HHmmss` (Windows), e.g.
`.claude-backup-20260817-143052`. Never reuse or overwrite an existing
backup folder — each run creates a new one.

On the known Windows machine the user profile is `C:\Users\wzy`. Resolve the
actual home directory at runtime (`$HOME` / `$env:USERPROFILE`) instead of
hardcoding it.

## Classification

### Identity / runtime — NEVER migrate (leave for regeneration)

These carry the old user identity or are regenerable machine state. All
entries refer to the **top level** of `.claude` only — a file or directory
with the same name nested deeper (e.g. inside a plugin or skill) is content
and MUST migrate:

- `.credentials.json` — OAuth access/refresh tokens (old account). On macOS
  credentials may instead live in the Keychain (item "Claude Code-credentials");
  logging out of the old account / logging into the new one replaces it.
- `config.json` — install/device state
- `telemetry`, `statsig` — anonymous/stable device IDs
- `session-env`, `shell-snapshots`, `ide` — runtime snapshots (may embed old
  plugin cache paths; not project memory, not skills)
- `mcp-health-cache.json`, `mcp-needs-auth-cache.json` — caches
- In `~/.claude.json` / `%USERPROFILE%\.claude.json`: the `oauthAccount` and
  `userID` fields (the rest of that file is migratable content — see step 6)

### Everything else — migrate automatically

Do NOT enumerate a whitelist. Copy the entire `.claude` tree minus the
exclusion list above. This automatically covers `projects`, `file-history`,
`sessions`, `history.jsonl`, `skills`, `agents`, `commands`, `plugins`,
`rules`, `hooks`, `mcp-configs`, `output-styles`, `plans`, `tasks`, `teams`,
`scripts`, `CLAUDE.md`, `AGENTS.md`, `RTK.md`, dot-directories like `.codex`
`.cursor` `.agents`, and anything added by future Claude Code versions.

`settings.json` is content, not identity, but the fresh install writes its
own: keep the newly generated file as base and deliberately merge old
permissions/hooks/plugin config into it (never blind-overwrite). Before
merging, check the old file for tokens/keys (`apiKeyHelper`, `env` secrets).

## Safe Workflow

### 0. Preconditions

- **Close every Claude Code session on this machine** (terminals, IDE
  extensions, desktop app) before steps 2–5. A live session keeps writing to
  `.claude`, which makes the backup inconsistent and can hold locks. If this
  workflow itself runs inside Claude Code on the same machine, do the
  read-only inspection here, then have the user run the backup/rename steps
  from a plain terminal (or quit all other sessions and accept that this one
  may add files after the backup — re-run the count check in step 2).
- **Check free disk space** is at least the size of `.claude` (the backup is
  a full copy):

macOS:

```bash
du -sh "$HOME/.claude"; df -h "$HOME"
```

Windows:

```powershell
"{0:N1} MB" -f ((Get-ChildItem (Join-Path $env:USERPROFILE ".claude") -Recurse -Force |
  Measure-Object Length -Sum).Sum / 1MB)
"{0:N1} GB free" -f ((Get-PSDrive $env:USERPROFILE[0]).Free / 1GB)
```

### 1. Inspect (read-only)

macOS:

```bash
ls -la "$HOME/.claude" 2>/dev/null
ls -la "$HOME/.claude.json" "$HOME/.claude.old" "$HOME/.claude.json.old" 2>/dev/null
```

Windows:

```powershell
$root = Join-Path $env:USERPROFILE ".claude"
Test-Path -LiteralPath $root
Test-Path -LiteralPath (Join-Path $env:USERPROFILE ".claude.json")
Test-Path -LiteralPath (Join-Path $env:USERPROFILE ".claude.old")
Test-Path -LiteralPath (Join-Path $env:USERPROFILE ".claude.json.old")
Get-ChildItem -LiteralPath $root -Force
```

### 2. Full timestamped backup (everything, including identity files)

The backup is complete on purpose — it is the rollback of last resort and is
deleted at the end as the final identity removal. The timestamp is precise to
the second.

macOS:

```bash
src="$HOME/.claude"
stamp=$(date +%Y%m%d-%H%M%S)   # precise to the second
dest="$HOME/claude-backups/.claude-backup-$stamp"
[ -e "$dest" ] && { echo "Backup dir already exists: $dest"; exit 1; }
mkdir -p "$dest"
rsync -a "$src/" "$dest/" || { echo "Backup failed"; exit 1; }
cp -p "$HOME/.claude.json" "$dest/.claude.json.top-level"
```

Windows:

```powershell
$src = Join-Path $env:USERPROFILE ".claude"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"   # precise to the second
$dest = Join-Path $env:USERPROFILE "Desktop\claude-backups\.claude-backup-$stamp"
if (Test-Path -LiteralPath $dest) { throw "Backup dir already exists: $dest" }
New-Item -ItemType Directory -Force -Path $dest | Out-Null
robocopy $src $dest /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /MT:8 /NFL /NDL /NP
if ($LASTEXITCODE -gt 7) { throw "Backup failed: $LASTEXITCODE" }
Copy-Item -LiteralPath (Join-Path $env:USERPROFILE ".claude.json") `
  -Destination (Join-Path $dest ".claude.json.top-level") -ErrorAction Stop
```

Verify before touching anything. Two checks: (a) every top-level item that
exists in the source also exists in the backup (dynamic — don't fail on dirs
this machine never had); (b) total item counts match (backup has exactly one
extra file: `.claude.json.top-level`). A count mismatch usually means a
Claude Code session was still writing — close it and re-run the backup.

macOS:

```bash
for f in "$src"/* "$src"/.*; do
  base=$(basename "$f")
  { [ "$base" = "." ] || [ "$base" = ".." ]; } && continue
  [ -e "$dest/$base" ] || { echo "Backup missing: $base"; exit 1; }
done
src_count=$(find "$src" | wc -l)
dest_count=$(find "$dest" | wc -l)
echo "source=$src_count backup=$dest_count (expect backup = source + 1)"
```

Windows:

```powershell
Get-ChildItem -LiteralPath $src -Force | ForEach-Object {
  if (-not (Test-Path -LiteralPath (Join-Path $dest $_.Name))) {
    throw "Backup missing: $($_.Name)"
  }
}
$srcCount = (Get-ChildItem -LiteralPath $src -Recurse -Force).Count
$destCount = (Get-ChildItem -LiteralPath $dest -Recurse -Force).Count
"source=$srcCount backup=$destCount (expect backup = source + 1)"
```

Note (macOS): if credentials live in the Keychain, they are NOT part of this
file backup. That is acceptable — the rollback path for the old account is
simply logging into it again.

### 3. Move the old identity aside (rename, don't delete)

Refuse to proceed if `.claude.old` or `.claude.json.old` already exists —
ask the user whether to remove or rename the previous one first. Never let
`mv` silently nest the new directory inside an existing `.claude.old`.

macOS:

```bash
[ -e "$HOME/.claude.old" ] && { echo ".claude.old already exists — resolve first"; exit 1; }
[ -e "$HOME/.claude.json.old" ] && { echo ".claude.json.old already exists — resolve first"; exit 1; }
mv "$HOME/.claude" "$HOME/.claude.old"
mv "$HOME/.claude.json" "$HOME/.claude.json.old"
```

Windows:

```powershell
if (Test-Path -LiteralPath (Join-Path $env:USERPROFILE ".claude.old")) {
  throw ".claude.old already exists - resolve first"
}
if (Test-Path -LiteralPath (Join-Path $env:USERPROFILE ".claude.json.old")) {
  throw ".claude.json.old already exists - resolve first"
}
Rename-Item -LiteralPath (Join-Path $env:USERPROFILE ".claude") -NewName ".claude.old"
Rename-Item -LiteralPath (Join-Path $env:USERPROFILE ".claude.json") -NewName ".claude.json.old"
```

If the rename fails (`Access denied` on Windows, `Resource busy` on macOS),
do not force it — Claude Code, VS Code, or node holds a handle. Ask the user
to close them and retry; as fallback, copy the verified backup to
`.claude.old` and tell the user.

### 4. Regenerate a fresh identity

Have the user launch Claude Code and log in with the new account. This
recreates `.claude`, `.claude.json`, credentials (file or macOS Keychain),
and fresh device/telemetry IDs. On macOS, if the old account used the
Keychain, run `/logout` inside Claude Code first (or delete the old
"Claude Code-credentials" Keychain item) so the new login does not reuse it.
Confirm login succeeded before migrating, then have the user quit Claude
Code again before step 5.

### 5. Auto-migrate everything except identity (single copy command)

All exclusions are anchored to the top level of the tree. Unanchored name
matching (plain `--exclude='config.json'` or `robocopy /XF config.json`)
would silently drop same-named files nested inside plugins/skills/projects —
that is a data-loss bug, never do it.

macOS (leading `/` anchors each pattern to the transfer root):

```bash
old="$HOME/.claude.old"
new="$HOME/.claude"
rsync -a \
  --exclude='/.credentials.json' \
  --exclude='/config.json' \
  --exclude='/settings.json' \
  --exclude='/mcp-health-cache.json' \
  --exclude='/mcp-needs-auth-cache.json' \
  --exclude='/telemetry/' \
  --exclude='/statsig/' \
  --exclude='/session-env/' \
  --exclude='/shell-snapshots/' \
  --exclude='/ide/' \
  "$old/" "$new/" || { echo "Migration failed"; exit 1; }
```

Windows (full paths anchor each exclusion to the top level):

```powershell
$old = Join-Path $env:USERPROFILE ".claude.old"
$new = Join-Path $env:USERPROFILE ".claude"
$xf = @(".credentials.json","config.json","settings.json",
        "mcp-health-cache.json","mcp-needs-auth-cache.json") |
      ForEach-Object { Join-Path $old $_ }
$xd = @("telemetry","statsig","session-env","shell-snapshots","ide") |
      ForEach-Object { Join-Path $old $_ }
robocopy $old $new /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /MT:8 /NFL /NDL /NP `
  /XF $xf /XD $xd
if ($LASTEXITCODE -gt 7) { throw "Migration failed: $LASTEXITCODE" }
```

Note: neither command deletes anything in the destination (`rsync` without
`--delete`, `robocopy` without `/MIR`), so fresh identity files are safe.
Excluding top-level `settings.json` protects the newly generated settings
from being overwritten (merge it deliberately per the Classification
section).

### 6. Merge migratable parts of `.claude.json`

The old top-level `.claude.json` holds per-project state (allowed tools, MCP
servers, prompt history) worth migrating — but also `oauthAccount`/`userID`.
Merge per-project entries into the new file (old entries win on conflict,
but entries the fresh login already created for other paths are kept) and
never copy identity fields.

macOS (requires `jq`; fall back to a small `node -e` script if absent):

```bash
jq -s '
  ((.[1].projects // {}) + (.[0].projects // {})) as $projects |
  .[1]
  + (if .[0].mcpServers != null then {mcpServers: .[0].mcpServers} else {} end)
  + {projects: $projects}
' "$HOME/.claude.json.old" "$HOME/.claude.json" > "$HOME/.claude.json.tmp" \
  && mv "$HOME/.claude.json.tmp" "$HOME/.claude.json"
# Deliberately NOT copied: oauthAccount, userID, firstStartTime
```

Windows:

```powershell
$oldPath = Join-Path $env:USERPROFILE ".claude.json.old"
$newPath = Join-Path $env:USERPROFILE ".claude.json"
$oldJson = Get-Content $oldPath -Raw | ConvertFrom-Json
$newJson = Get-Content $newPath -Raw | ConvertFrom-Json
if ($oldJson.PSObject.Properties["projects"]) {
  if (-not $newJson.PSObject.Properties["projects"]) {
    $newJson | Add-Member -NotePropertyName projects -NotePropertyValue ([pscustomobject]@{})
  }
  foreach ($p in $oldJson.projects.PSObject.Properties) {
    $newJson.projects | Add-Member -Force -NotePropertyName $p.Name -NotePropertyValue $p.Value
  }
}
if ($oldJson.PSObject.Properties["mcpServers"]) {
  $newJson | Add-Member -Force -NotePropertyName mcpServers -NotePropertyValue $oldJson.mcpServers
}
# Deliberately NOT copied: oauthAccount, userID, firstStartTime
$newJson | ConvertTo-Json -Depth 50 | Set-Content $newPath
```

### 7. Identity-leak scan

After migration, confirm no old-identity markers remain. Ask the user for
the old account email, user ID, and account/organization UUIDs (all visible
in the backed-up `.claude.json.top-level` under `oauthAccount`) if not
already known. Scan BOTH the new `.claude` tree AND the new top-level
`.claude.json`.

macOS:

```bash
patterns=(-e "old-email@example.com" -e "OLD_USER_ID" -e "OLD_ACCOUNT_UUID" -e "OLD_ORG_UUID")
grep -r -l "${patterns[@]}" \
  --include='*.json' --include='*.jsonl' --include='*.md' --include='*.txt' \
  "$HOME/.claude" "$HOME/.claude.json" || echo "clean"
```

Windows:

```powershell
$patterns = @("old-email@example.com", "OLD_USER_ID", "OLD_ACCOUNT_UUID", "OLD_ORG_UUID")
$targets = Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE ".claude") `
  -Recurse -File -Include *.json,*.jsonl,*.md,*.txt
$targets += Get-Item -LiteralPath (Join-Path $env:USERPROFILE ".claude.json")
$targets | Select-String -Pattern $patterns -List | Select-Object Path, LineNumber
```

Any hit must be reported and cleaned (or the file re-classified) before
declaring the migration done. Expected hits inside `projects`/session
transcripts that merely mention the old email in conversation content are
for the user to judge — report them, don't silently delete.

### 8. Verify

- Migrated top-level items in the new `.claude` match the old tree minus the
  exclusion list (compare directory listings, not a fixed name list).
- New identity is the fresh one: credentials (file mtime after the new login,
  or macOS Keychain item for the new account); `settings.json` was not
  overwritten; `.claude.json` has the NEW `oauthAccount`/`userID`.
- Excluded state is absent or fresh: `telemetry`, `statsig`, `session-env`,
  `shell-snapshots`, `ide`, `config.json`, `mcp-health-cache.json`,
  `mcp-needs-auth-cache.json`.
- Identity-leak scan (step 7) came back clean or all hits were reviewed.
- Claude Code starts, skills/agents/plugins load, project memory resolves.

### 9. Retention and final deletion (user-confirmed, manual)

Do NOT delete anything in the same session as the migration. Tell the user:

- `.claude.old`, `.claude.json.old`, and the timestamped backup are the only
  remaining copies of the old identity and the rollback path.
- They should use the new setup for a while and confirm nothing is missing.

Only when the user explicitly confirms and asks for removal, delete all three
— this is the step that fully removes the old user identity. On macOS also
delete the old account's Keychain item if one remains.

macOS:

```bash
for t in "$HOME/.claude.old" "$HOME/.claude.json.old" \
         "$HOME/claude-backups/.claude-backup-YYYYMMDD-HHMMSS"; do
  case "$t" in
    "$HOME"/.claude.old|"$HOME"/.claude.json.old|"$HOME"/claude-backups/.claude-backup-*) ;;
    *) echo "Refusing unexpected path: $t"; exit 1 ;;
  esac
  if [ -e "$t" ]; then rm -rf "$t"; fi
done
```

Windows:

```powershell
$targets = @(
  (Join-Path $env:USERPROFILE ".claude.old"),
  (Join-Path $env:USERPROFILE ".claude.json.old"),
  (Join-Path $env:USERPROFILE "Desktop\claude-backups\.claude-backup-YYYYMMDD-HHMMSS")
)
foreach ($t in $targets) {
  if (Test-Path -LiteralPath $t) {
    Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction Stop
  }
}
```

Never run this on the user's behalf proactively, never while the active
`.claude` has not passed step 8, and refuse if the resolved path is not one
of the expected targets.

## Other machine state (optional, mention to the user)

Outside `.claude`, Claude Code may keep caches/logs that can reference the
old install but carry no account identity. Not part of the default workflow;
offer them as optional cleanup only if present:

- macOS: `~/Library/Caches/claude-cli-nodejs` (MCP/tool logs, caches)
- Windows: `%LOCALAPPDATA%\claude-cli-nodejs` (if present)
- Native-install binaries/versions (e.g. `~/.local/share/claude`,
  `~/.local/bin/claude`) — reinstall artifacts, safe to keep.

## Reporting

Report the detected platform, exact paths, and pass/fail for each stage:
preconditions (sessions closed, disk space), backup created (folder name with
its to-the-second timestamp) and verified (per-item + count check), identity
regenerated, migration exit code, `.claude.json` merge result, identity-leak
scan result, post-migration verification. If any step is blocked by file
locks or access denied, stop and explain the current state instead of forcing
deletion. Always end the migration report by listing what still holds the old
identity (`.claude.old`, backups, old Keychain item on macOS) and that
deletion waits for the user's explicit confirmation.

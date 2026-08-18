---
name: private-claude-code-state-reset
description: Safely reset Claude Code local state on macOS or Windows and migrate it to a fresh user identity. Full backup first (timestamped to the second), then auto-migrate everything (projects memory, sessions, history, skills, agents, plugins, rules, hooks) into the new identity, excluding only old-identity state (credentials, device/telemetry IDs, account fields). Also resets the Claude Desktop app's separate login state (claude.ai session stores, macOS Keychain "Claude Safe Storage") while keeping claude_desktop_config.json MCP config. Old data is kept as backup until the user confirms, then deleted manually. Use when the user asks to delete/recreate ~/.claude or %USERPROFILE%\.claude, regenerate Claude Code machine code/device identity, switch to a new account while keeping all data, log out/reset the Claude Desktop app identity, decide which .claude files are identity vs migratable content, debug why the old account still shows after deleting ~/.claude (Keychain), or clear the remaining login layers (MCP OAuth, browser claude.ai session). Always runs the full reset-and-migrate workflow (Level B); a plain re-login without reset is out of scope.
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

## Level: this skill always runs the full reset (Level B)

Claude login state is layered — Claude Code (CLI), the Claude Desktop app,
the browser's claude.ai session, and per-MCP-server OAuth are separate
stores that do not share credentials. Deleting `~/.claude` clears only the
first, and on macOS not even that (Keychain items survive file deletion).

This skill's job is **Level B — full identity reset with content
migration**: new account AND fresh device/telemetry identity, keeping all
content. When this skill is invoked, run Level B (steps 0–9 plus the Claude
Desktop section) directly — do not ask the user to pick a level.

For background only, **Level A — a login-only account switch** exists
outside this skill: `/logout` inside Claude Code, then log in again (some
builds also expose `claude auth logout` / `claude auth status` — verify
with `claude --help`); Claude Desktop Settings → Account → Log Out, Cmd+Q
(fully quit, not just close the window), relaunch, new login; browser: log
out of claude.ai or clear its site data (claude.ai Settings can also log
out ALL active sessions remotely). Level A keeps config, history, AND the
old device identity — it is not a reset. Mention it only if the user
explicitly says they just want to re-login without resetting anything, and
never delete `~/.claude` for that case.

If after any logout/reset Claude Code still recognizes the old account, the
leftover is almost always a macOS Keychain item — see "Troubleshooting: old
account survives a reset" below.

## Platform Detection

Detect the platform first, then use the matching command variant throughout:

- **macOS / Linux**: `uname` prints `Darwin`/`Linux`. Use bash/zsh + `rsync`.
- **Windows**: use **PowerShell 7+ (`pwsh`)** + `robocopy`. PowerShell 7 is a
  hard requirement, not a preference: Windows PowerShell 5.1 writes non-UTF-8
  by default on `Set-Content` (corrupts non-ASCII prompt history and paths in
  the step-6 merge) and its `ConvertFrom-Json` fails on large files (~2 MB+),
  which `.claude.json` easily reaches. Verify before any write step:
  `pwsh -NoProfile -Command '$PSVersionTable.PSVersion'` (major version ≥ 7);
  if `pwsh` is missing, stop and have the user install PowerShell 7 first.
  In this workspace run PowerShell via `rtk proxy pwsh -NoProfile -Command ...`.

Path map (same roles on both platforms):

| Role                    | macOS                        | Windows                              |
| ----------------------- | ---------------------------- | ------------------------------------ |
| Active config           | `~/.claude`                  | `%USERPROFILE%\.claude`              |
| Top-level account config (identity-bearing) | `~/.claude.json` | `%USERPROFILE%\.claude.json`     |
| Local rollback copy     | `~/.claude.old` (+ `~/.claude.json.old`) | `%USERPROFILE%\.claude.old` (+ `.claude.json.old`) |
| Timestamped backups     | `~/claude-backups/.claude-backup-*` | `%USERPROFILE%\claude-backups\.claude-backup-*` |

Linux uses the macOS layout and commands, with two simplifications: there is
no Keychain, so credentials always live in `~/.claude/.credentials.json`
(the file path the exclusion list already covers), and the Claude Desktop
section normally does not apply.

Backup folder names embed a timestamp precise to the second:
`%Y%m%d-%H%M%S` (macOS) / `yyyyMMdd-HHmmss` (Windows), e.g.
`.claude-backup-20260817-143052`. Never reuse or overwrite an existing
backup folder — each run creates a new one.

Backups contain plaintext OAuth tokens (`.credentials.json`), so their
location and permissions are security-sensitive: keep them directly under the
home directory — NEVER under `Desktop`, `Documents`, or any folder that
OneDrive/iCloud "known folder backup" may sync to the cloud — and restrict
the backup root to the current user (step 2 does this).

**Legacy Desktop backups**: an older revision of this skill wrote Windows
backups to `%USERPROFILE%\Desktop\claude-backups`. During step 1, check for
that folder; if it exists, move its contents to the proper backup root before
doing anything else — those folders hold old-account tokens and may already
be syncing to OneDrive:

```powershell
$legacy = Join-Path $env:USERPROFILE "Desktop\claude-backups"
$root   = Join-Path $env:USERPROFILE "claude-backups"
if (Test-Path -LiteralPath $legacy) {
  New-Item -ItemType Directory -Force -Path $root | Out-Null
  icacls $root /inheritance:r /grant:r "${env:USERNAME}:(OI)(CI)F" | Out-Null
  Get-ChildItem -LiteralPath $legacy -Force |
    Move-Item -Destination $root -ErrorAction Stop   # name collision = stop, report
  Remove-Item -LiteralPath $legacy -Force   # non-recursive: only removes if emptied
}
```

If the Desktop was OneDrive-synced, tell the user the moved backups may still
exist in OneDrive's cloud copy / recycle bin — removing them there (and
rotating the old account's credentials if exposure matters) is on the user.

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
permissions/hooks/plugin config into it (never blind-overwrite). Step 6b
performs this merge. Before merging, check the old file for tokens/keys
(`apiKeyHelper`, `env` secrets).

**MCP OAuth credentials** (third-party services the user authorized MCP
servers against — GitHub, Google, …) are deliberately NOT on the exclusion
list: they belong to those services, not to the Claude account, so they
migrate along with the MCP config and keep working after the account
switch. `claude auth logout` / `/logout` does not touch them. Only when the
goal is a full scrub rather than a migration, offer to clear them too:
list servers with `claude mcp list`, use a per-server logout if the
installed version has one (verify with `claude mcp --help`), and on macOS
check for MCP-related Keychain items alongside the Claude Code ones.

Known tradeoff of the blacklist approach: an identity-bearing file introduced
by a future Claude Code version would migrate by default. The step-7
identity-leak scan is the backstop — treat any unfamiliar top-level file that
the scan flags as a candidate for the exclusion list, and report it.

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
"{0:N1} MB" -f ((Get-ChildItem (Join-Path $env:USERPROFILE ".claude") -Recurse -Force -File |
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
# Legacy backup location from an older revision of this skill - if true,
# relocate it first (see "Legacy Desktop backups" above)
Test-Path -LiteralPath (Join-Path $env:USERPROFILE "Desktop\claude-backups")
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
chmod 700 "$HOME/claude-backups" "$dest"   # backup holds plaintext tokens
rsync -a "$src/" "$dest/" || { echo "Backup failed"; exit 1; }
cp -p "$HOME/.claude.json" "$dest/.claude.json.top-level" \
  || { echo "Top-level .claude.json backup failed"; exit 1; }
```

Windows:

```powershell
$src = Join-Path $env:USERPROFILE ".claude"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"   # precise to the second
$dest = Join-Path $env:USERPROFILE "claude-backups\.claude-backup-$stamp"
if (Test-Path -LiteralPath $dest) { throw "Backup dir already exists: $dest" }
New-Item -ItemType Directory -Force -Path $dest | Out-Null
# Backup holds plaintext tokens - restrict to the current user (best effort)
icacls (Split-Path $dest) /inheritance:r /grant:r "${env:USERNAME}:(OI)(CI)F" | Out-Null
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

The verification block is deliberately self-contained: it re-derives the
paths and picks the newest backup by name, because shell state (variables
like `$src`/`$dest`) does not persist between separate tool invocations.
Never rely on variables from the previous block here — with them unset the
per-item check would vacuously pass against `/`.

macOS (uses `find` for top-level enumeration — immune to bash/zsh glob
differences and to a dotfile-less `.claude`):

```bash
src="$HOME/.claude"
dest=$(ls -d "$HOME/claude-backups"/.claude-backup-* 2>/dev/null | sort | tail -1)
[ -n "$dest" ] && [ -d "$dest" ] \
  || { echo "No backup dir found under ~/claude-backups"; exit 1; }
echo "Verifying against: $dest"
missing=0
while IFS= read -r f; do
  base=$(basename "$f")
  { [ -e "$dest/$base" ] || [ -L "$dest/$base" ]; } \
    || { echo "Backup missing: $base"; missing=1; }
done < <(find "$src" -mindepth 1 -maxdepth 1)
[ "$missing" -eq 0 ] || exit 1
src_count=$(find "$src" | wc -l)
dest_count=$(find "$dest" | wc -l)
echo "source=$src_count backup=$dest_count (expect backup = source + 1)"
```

Windows:

```powershell
# Self-contained: re-derive paths, pick the newest backup by name
$src = Join-Path $env:USERPROFILE ".claude"
$dest = Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE "claude-backups") `
  -Directory -Force -Filter ".claude-backup-*" |
  Sort-Object Name | Select-Object -Last 1 -ExpandProperty FullName
if (-not $dest) { throw "No backup dir found under claude-backups" }
"Verifying against: $dest"
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
[ -e "$HOME/.claude" ] || { echo "~/.claude not found — nothing to rename"; exit 1; }
[ -e "$HOME/.claude.json" ] || { echo "~/.claude.json not found — nothing to rename"; exit 1; }
[ -e "$HOME/.claude.old" ] && { echo ".claude.old already exists — resolve first"; exit 1; }
[ -e "$HOME/.claude.json.old" ] && { echo ".claude.json.old already exists — resolve first"; exit 1; }
mv "$HOME/.claude" "$HOME/.claude.old" || { echo "Rename failed — nothing changed"; exit 1; }
if ! mv "$HOME/.claude.json" "$HOME/.claude.json.old"; then
  # Restore the consistent pre-step state; report honestly if that also fails
  if mv "$HOME/.claude.old" "$HOME/.claude"; then
    echo "Second rename failed — rolled back .claude.old to .claude"
  else
    echo "Second rename failed AND rollback failed — current state:"
    echo "  ~/.claude.old exists, ~/.claude missing, ~/.claude.json untouched."
    echo "Restore manually: mv ~/.claude.old ~/.claude"
  fi
  exit 1
fi
```

Windows:

```powershell
foreach ($p in @(".claude", ".claude.json")) {
  if (-not (Test-Path -LiteralPath (Join-Path $env:USERPROFILE $p))) {
    throw "$p not found - nothing to rename"
  }
}
if (Test-Path -LiteralPath (Join-Path $env:USERPROFILE ".claude.old")) {
  throw ".claude.old already exists - resolve first"
}
if (Test-Path -LiteralPath (Join-Path $env:USERPROFILE ".claude.json.old")) {
  throw ".claude.json.old already exists - resolve first"
}
Rename-Item -LiteralPath (Join-Path $env:USERPROFILE ".claude") -NewName ".claude.old" -ErrorAction Stop
try {
  Rename-Item -LiteralPath (Join-Path $env:USERPROFILE ".claude.json") -NewName ".claude.json.old" -ErrorAction Stop
} catch {
  # Restore the consistent pre-step state; report honestly if that also fails
  try {
    Rename-Item -LiteralPath (Join-Path $env:USERPROFILE ".claude.old") -NewName ".claude" -ErrorAction Stop
  } catch {
    throw ("Second rename failed AND rollback failed - current state: " +
      ".claude.old exists, .claude missing, .claude.json untouched. " +
      "Restore manually: Rename-Item .claude.old .claude")
  }
  throw "Second rename failed - rolled back .claude.old to .claude"
}
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
[ -d "$old" ] || { echo "$old not found"; exit 1; }
[ -d "$new" ] || { echo "Fresh ~/.claude missing — complete step 4 (new login) first"; exit 1; }
[ -f "$HOME/.claude.json" ] || { echo "Fresh ~/.claude.json missing — complete step 4 first"; exit 1; }
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
if (-not (Test-Path -LiteralPath $old)) { throw "$old not found" }
if (-not (Test-Path -LiteralPath $new)) {
  throw "Fresh .claude missing - complete step 4 (new login) first"
}
if (-not (Test-Path -LiteralPath (Join-Path $env:USERPROFILE ".claude.json"))) {
  throw "Fresh .claude.json missing - complete step 4 first"
}
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
from being overwritten (step 6b merges it deliberately).

### 6. Merge migratable parts of `.claude.json`

The old top-level `.claude.json` holds per-project state (allowed tools, MCP
servers, prompt history) plus global preferences worth migrating — but also
`oauthAccount`/`userID`. Consistent with the tree migration, the merge is
blacklist-based: copy ALL top-level fields from the old file EXCEPT the
identity blacklist (`oauthAccount`, `userID`, `firstStartTime`); old fields
win on conflict. `projects` is merged per-key instead of replaced, so entries
the fresh login already created for other paths are kept (old entries win on
a same-path conflict). The write is atomic (tmp file + rename), so a failure
mid-merge cannot corrupt the new file.

macOS, with `jq`:

```bash
jq -s '
  (.[0] | del(.oauthAccount, .userID, .firstStartTime)) as $old |
  ((.[1].projects // {}) + ($old.projects // {})) as $projects |
  .[1] + $old + {projects: $projects}
' "$HOME/.claude.json.old" "$HOME/.claude.json" > "$HOME/.claude.json.tmp" \
  && mv "$HOME/.claude.json.tmp" "$HOME/.claude.json"
# Identity blacklist (never copied): oauthAccount, userID, firstStartTime
```

macOS fallback if `jq` is absent (`node` ships with Claude Code installs):

```bash
node -e '
const fs = require("fs");
const [oldP, newP] = process.argv.slice(1);
const IDENTITY = ["oauthAccount", "userID", "firstStartTime"];
const oldJ = JSON.parse(fs.readFileSync(oldP, "utf8"));
const newJ = JSON.parse(fs.readFileSync(newP, "utf8"));
const merged = { ...newJ };
for (const [k, v] of Object.entries(oldJ)) {
  if (IDENTITY.includes(k) || k === "projects") continue;
  merged[k] = v;
}
merged.projects = { ...(newJ.projects || {}), ...(oldJ.projects || {}) };
fs.writeFileSync(newP + ".tmp", JSON.stringify(merged, null, 2));
fs.renameSync(newP + ".tmp", newP);
' "$HOME/.claude.json.old" "$HOME/.claude.json"
```

Windows:

```powershell
# Requires PowerShell 7+ (see Platform Detection) - 5.1 corrupts encoding here
$oldPath = Join-Path $env:USERPROFILE ".claude.json.old"
$newPath = Join-Path $env:USERPROFILE ".claude.json"
$tmpPath = "$newPath.tmp"
$identity = @("oauthAccount", "userID", "firstStartTime")
$oldJson = Get-Content -LiteralPath $oldPath -Raw | ConvertFrom-Json
$newJson = Get-Content -LiteralPath $newPath -Raw | ConvertFrom-Json
foreach ($prop in $oldJson.PSObject.Properties) {
  if ($identity -contains $prop.Name -or $prop.Name -eq "projects") { continue }
  $newJson | Add-Member -Force -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
}
if ($oldJson.PSObject.Properties["projects"] -and $null -ne $oldJson.projects) {
  if (-not $newJson.PSObject.Properties["projects"]) {
    $newJson | Add-Member -NotePropertyName projects -NotePropertyValue ([pscustomobject]@{})
  }
  foreach ($p in $oldJson.projects.PSObject.Properties) {
    $newJson.projects | Add-Member -Force -NotePropertyName $p.Name -NotePropertyValue $p.Value
  }
}
# Identity blacklist (never copied): oauthAccount, userID, firstStartTime
$newJson | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $tmpPath -Encoding utf8
Move-Item -LiteralPath $tmpPath -Destination $newPath -Force
```

### 6b. Merge old `settings.json` (deliberate, not blind)

Step 5 excluded top-level `settings.json` so the fresh install's file stays
the base. Now merge the old configuration into it: old top-level keys win,
except `permissions`, `env`, and `hooks`, which are merged object-key by
object-key (old entries win on conflict) — and `permissions.allow` /
`permissions.deny`, which become the union of both lists. The write is
atomic (tmp file + rename), same as step 6.

**Before merging, inspect the old file for secrets.** `apiKeyHelper` and
`env` may hold tokens or keys bound to the old account — anything
account-specific must NOT be carried over. Show any hits to the user and
strip them (from a working copy of the old file) before running the merge:

macOS:

```bash
grep -nE '"apiKeyHelper"|"env"' "$HOME/.claude.old/settings.json" \
  || echo "no apiKeyHelper/env keys in old settings"
```

Windows:

```powershell
Select-String -LiteralPath (Join-Path $env:USERPROFILE ".claude.old\settings.json") `
  -SimpleMatch -Pattern '"apiKeyHelper"', '"env"'
```

macOS, with `jq`:

```bash
old_s="$HOME/.claude.old/settings.json"
new_s="$HOME/.claude/settings.json"
[ -f "$old_s" ] || { echo "No old settings.json — skip"; exit 0; }
[ -f "$new_s" ] || echo '{}' > "$new_s"
jq -s '
  def uniq(a; b): ((a // []) + (b // [])) | unique;
  .[0] as $old | .[1] as $new |
  ($new + $old)
  + (if ($old.permissions or $new.permissions) then
       {permissions: ((($new.permissions // {}) + ($old.permissions // {}))
         + (if ($old.permissions.allow or $new.permissions.allow) then
              {allow: uniq($new.permissions.allow; $old.permissions.allow)}
            else {} end)
         + (if ($old.permissions.deny or $new.permissions.deny) then
              {deny: uniq($new.permissions.deny; $old.permissions.deny)}
            else {} end))}
     else {} end)
  + (if ($old.env or $new.env) then
       {env: (($new.env // {}) + ($old.env // {}))} else {} end)
  + (if ($old.hooks or $new.hooks) then
       {hooks: (($new.hooks // {}) + ($old.hooks // {}))} else {} end)
' "$old_s" "$new_s" > "$new_s.tmp" && mv "$new_s.tmp" "$new_s"
```

macOS fallback if `jq` is absent:

```bash
node -e '
const fs = require("fs");
const [oldP, newP] = process.argv.slice(1);
if (!fs.existsSync(oldP)) { console.log("No old settings.json - skip"); process.exit(0); }
const oldJ = JSON.parse(fs.readFileSync(oldP, "utf8"));
const newJ = fs.existsSync(newP) ? JSON.parse(fs.readFileSync(newP, "utf8")) : {};
const DEEP = ["permissions", "env", "hooks"];
const merged = { ...newJ };
for (const [k, v] of Object.entries(oldJ)) {
  if (DEEP.includes(k)) continue;
  merged[k] = v;
}
for (const k of DEEP) {
  if (oldJ[k] == null && newJ[k] == null) continue;
  merged[k] = { ...(newJ[k] || {}), ...(oldJ[k] || {}) };
}
if (merged.permissions) {
  for (const list of ["allow", "deny"]) {
    const union = [...new Set([
      ...(newJ.permissions?.[list] || []),
      ...(oldJ.permissions?.[list] || []),
    ])];
    if (union.length) merged.permissions[list] = union;
  }
}
fs.writeFileSync(newP + ".tmp", JSON.stringify(merged, null, 2));
fs.renameSync(newP + ".tmp", newP);
' "$HOME/.claude.old/settings.json" "$HOME/.claude/settings.json"
```

Windows:

```powershell
# Requires PowerShell 7+ (see Platform Detection)
$oldPath = Join-Path $env:USERPROFILE ".claude.old\settings.json"
$newPath = Join-Path $env:USERPROFILE ".claude\settings.json"
$tmpPath = "$newPath.tmp"
if (-not (Test-Path -LiteralPath $oldPath)) { "No old settings.json - skip"; return }
$oldJson = Get-Content -LiteralPath $oldPath -Raw | ConvertFrom-Json
$newJson = if (Test-Path -LiteralPath $newPath) {
  Get-Content -LiteralPath $newPath -Raw | ConvertFrom-Json
} else { [pscustomobject]@{} }

# Capture allow/deny from BOTH originals before any overwrite
function Get-PermList($json, $name) {
  $perm = $json.PSObject.Properties["permissions"]
  if ($perm -and $perm.Value -and $perm.Value.PSObject.Properties[$name]) {
    @($perm.Value.$name)
  } else { @() }
}
$allow = @(((Get-PermList $newJson "allow") + (Get-PermList $oldJson "allow")) |
  Select-Object -Unique)
$deny = @(((Get-PermList $newJson "deny") + (Get-PermList $oldJson "deny")) |
  Select-Object -Unique)

$deepKeys = @("permissions", "env", "hooks")
foreach ($prop in $oldJson.PSObject.Properties) {
  if ($deepKeys -contains $prop.Name) { continue }
  $newJson | Add-Member -Force -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
}
foreach ($k in $deepKeys) {
  $oProp = $oldJson.PSObject.Properties[$k]
  if (-not $oProp -or $null -eq $oProp.Value) { continue }
  $nProp = $newJson.PSObject.Properties[$k]
  if (-not $nProp -or $null -eq $nProp.Value) {
    $newJson | Add-Member -Force -NotePropertyName $k -NotePropertyValue $oProp.Value
    continue
  }
  $merged = [pscustomobject]@{}
  foreach ($p in $nProp.Value.PSObject.Properties) {
    $merged | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value
  }
  foreach ($p in $oProp.Value.PSObject.Properties) {
    $merged | Add-Member -Force -NotePropertyName $p.Name -NotePropertyValue $p.Value
  }
  $newJson | Add-Member -Force -NotePropertyName $k -NotePropertyValue $merged
}
if ($newJson.PSObject.Properties["permissions"] -and $newJson.permissions) {
  if ($allow.Count) {
    $newJson.permissions | Add-Member -Force -NotePropertyName allow -NotePropertyValue $allow
  }
  if ($deny.Count) {
    $newJson.permissions | Add-Member -Force -NotePropertyName deny -NotePropertyValue $deny
  }
}
$newJson | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $tmpPath -Encoding utf8
Move-Item -LiteralPath $tmpPath -Destination $newPath -Force
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
grep -r -l -F "${patterns[@]}" \
  --include='*.json' --include='*.jsonl' --include='*.md' --include='*.txt' \
  "$HOME/.claude" "$HOME/.claude.json"
scan_status=$?   # not "status" — read-only special variable in zsh
case $scan_status in
  0) echo "LEAKS FOUND (files listed above) — review before proceeding" ;;
  1) echo "clean" ;;
  *) echo "Scan FAILED (grep exit $scan_status) — do NOT treat as clean"; exit 1 ;;
esac
```

Windows:

```powershell
$patterns = @("old-email@example.com", "OLD_USER_ID", "OLD_ACCOUNT_UUID", "OLD_ORG_UUID")
$targets = @(Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE ".claude") `
  -Recurse -File -Include *.json,*.jsonl,*.md,*.txt)
$targets += Get-Item -LiteralPath (Join-Path $env:USERPROFILE ".claude.json")
$hits = $targets | Select-String -SimpleMatch -Pattern $patterns -List
if ($hits) {
  $hits | Select-Object Path, LineNumber
  "LEAKS FOUND - review before proceeding"
} else { "clean" }
```

Any hit must be reported and cleaned (or the file re-classified) before
declaring the migration done. Expected hits inside `projects`/session
transcripts that merely mention the old email in conversation content are
for the user to judge — report them, don't silently delete.

Scope note: the scan covers text formats (`.json`, `.jsonl`, `.md`, `.txt`)
only. Binary or extension-less stores (e.g. `__store.db`) are out of scope —
state this limitation in the final report.

### 8. Verify

- Migrated top-level items in the new `.claude` match the old tree minus the
  exclusion list (compare directory listings, not a fixed name list).
- New identity is the fresh one: credentials (file mtime after the new login,
  or macOS Keychain item for the new account); `settings.json` was not
  overwritten AND the step-6b merge was applied (old permissions/hooks
  present, no old-account secrets carried over) — or the user explicitly
  skipped the merge; `.claude.json` has the NEW `oauthAccount`/`userID`.
- Excluded state is absent or fresh: `telemetry`, `statsig`, `session-env`,
  `shell-snapshots`, `ide`, `config.json`, `mcp-health-cache.json`,
  `mcp-needs-auth-cache.json`.
- Identity-leak scan (step 7) came back clean or all hits were reviewed.
- Claude Code starts, skills/agents/plugins load, project memory resolves.

### 9. Retention and final deletion (user-confirmed, manual)

Do NOT delete anything in the same session as the migration. Tell the user:

- `.claude.old`, `.claude.json.old`, and the timestamped backup are the only
  remaining copies of the old identity and the rollback path — plus
  `Claude.old` and the `claude-desktop-backup-*` folder if the Claude Desktop
  reset was also performed.
- They should use the new setup for a while and confirm nothing is missing.

Only when the user explicitly confirms and asks for removal, delete every
remaining item (up to five when the desktop reset was also performed) — this
is the step that fully removes the old user identity. On macOS also delete
any old-account Keychain items that remain: "Claude Code-credentials"
(Claude Code) — "Claude Safe Storage" was already replaced during the desktop
reset if that path was taken.

macOS:

```bash
for t in "$HOME/.claude.old" "$HOME/.claude.json.old" \
         "$HOME/Library/Application Support/Claude.old" \
         "$HOME/claude-backups/.claude-backup-YYYYMMDD-HHMMSS" \
         "$HOME/claude-backups/claude-desktop-backup-YYYYMMDD-HHMMSS"; do
  case "$t" in
    *..*) echo "Refusing path containing ..: $t"; exit 1 ;;   # blocks traversal past the guard
  esac
  case "$t" in
    "$HOME"/.claude.old|"$HOME"/.claude.json.old) ;;
    "$HOME/Library/Application Support/Claude.old") ;;
    "$HOME"/claude-backups/.claude-backup-*) ;;
    "$HOME"/claude-backups/claude-desktop-backup-*) ;;
    *) echo "Refusing unexpected path: $t"; exit 1 ;;
  esac
  if [ -e "$t" ]; then rm -rf "$t"; fi
done
# Old-account Claude Code Keychain item (loop: delete every matching copy)
while security delete-generic-password -s "Claude Code-credentials" >/dev/null 2>&1; do :; done
```

Windows:

```powershell
$backupPrefixes = @(
  (Join-Path $env:USERPROFILE "claude-backups\.claude-backup-"),
  (Join-Path $env:USERPROFILE "claude-backups\claude-desktop-backup-")
)
$targets = @(
  (Join-Path $env:USERPROFILE ".claude.old"),
  (Join-Path $env:USERPROFILE ".claude.json.old"),
  (Join-Path $env:APPDATA "Claude.old"),
  (Join-Path $env:USERPROFILE "claude-backups\.claude-backup-YYYYMMDD-HHMMSS"),
  (Join-Path $env:USERPROFILE "claude-backups\claude-desktop-backup-YYYYMMDD-HHMMSS")
)
$allowed = @(
  (Join-Path $env:USERPROFILE ".claude.old"),
  (Join-Path $env:USERPROFILE ".claude.json.old"),
  (Join-Path $env:APPDATA "Claude.old")
)
foreach ($t in $targets) {
  if ($t -like "*..*") { throw "Refusing path containing ..: $t" }  # blocks traversal past the guard
  $isBackup = @($backupPrefixes | Where-Object { $t.StartsWith($_) }).Count -gt 0
  if (-not (($allowed -contains $t) -or $isBackup)) {
    throw "Refusing unexpected path: $t"
  }
  if (Test-Path -LiteralPath $t) {
    Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction Stop
  }
}
```

Never run this on the user's behalf proactively, never while the active
`.claude` has not passed step 8, and refuse if the resolved path is not one
of the expected targets. The guard deliberately refuses Desktop paths: if a
legacy `Desktop\claude-backups` still exists at this point, relocate it per
"Legacy Desktop backups" first — never delete backups in place on Desktop,
since OneDrive may have a cloud copy that would silently outlive the local
deletion.

## Troubleshooting: old account survives a reset

Symptom: `~/.claude` was deleted or renamed (or `/logout` was run), Claude
Code restarts — and still shows the OLD account. On macOS this is expected
whenever the old login used the Keychain: `~/.claude` and the Keychain are
two independent stores, and file deletion never touches the latter. Check
in this order:

1. macOS Keychain: open Keychain Access and search for `Claude`,
   `Anthropic`, and `Claude Code`. Confirm an item actually belongs to
   Claude / Anthropic before deleting it (other tools may have
   similar-sounding entries). The Claude Code item is
   "Claude Code-credentials"; the Desktop app's key is
   "Claude Safe Storage".
2. A stale `~/.claude/.credentials.json` (or
   `%USERPROFILE%\.claude\.credentials.json` on Windows) left behind by a
   partial cleanup.
3. A still-running Claude Code / Claude Desktop process holding the old
   session in memory — quit it fully (Cmd+Q, not window close) and retry.
4. The browser's claude.ai login — separate from both apps; log out there
   if the goal is a complete switch.

## Claude Desktop (desktop app) login state

The Claude Desktop app keeps its login completely separate from Claude Code —
resetting `.claude` does NOT touch it. Handle it whenever the desktop app is
installed and the goal is a full identity switch. Same principles apply:
backup first, rename instead of delete, user confirms final deletion.

Path map:

| Role                        | macOS                                  | Windows                          |
| --------------------------- | -------------------------------------- | -------------------------------- |
| App data (session + config) | `~/Library/Application Support/Claude` | `%APPDATA%\Claude`               |
| Local rollback copy         | `~/Library/Application Support/Claude.old` | `%APPDATA%\Claude.old`       |
| Timestamped backups         | `~/claude-backups/claude-desktop-backup-*` | `%USERPROFILE%\claude-backups\claude-desktop-backup-*` |
| Installer/binaries (keep)   | `/Applications/Claude.app`             | `%LOCALAPPDATA%\AnthropicClaude` |

Classification inside the app data directory:

- **Identity/session — never migrate**: the Electron profile stores
  (`Cookies` — possibly under `Network/` — `Local Storage/`,
  `Session Storage/`, `IndexedDB/`) hold the claude.ai session tokens,
  encrypted via the macOS Keychain item "Claude Safe Storage" or Windows
  DPAPI. Plus regenerable state (`Cache*`, `GPUCache`, `Crashpad`, `sentry/`,
  window state). The whole-directory reset below covers them wherever they
  live in the profile.
- **Content — migrate**: `claude_desktop_config.json` (MCP server config).
  It is account-independent; before copying, check its MCP `env` blocks for
  account-specific tokens.

**Preferred path — in-app account switch, no file surgery**: in the app,
Settings → log out of the old account → log in with the new one. The session
stores are rewritten for the new identity and `claude_desktop_config.json`
stays as is. Prefer this whenever the app is usable.

**File-level reset** (when in-app logout is not possible or not trusted):

macOS:

```bash
appdata="$HOME/Library/Application Support/Claude"
[ -d "$appdata" ] || { echo "Claude Desktop not installed — skip"; exit 0; }
# -f matches helper processes too ("Claude Helper (Renderer)" etc. live under Claude.app)
pgrep -f "Claude.app" >/dev/null && { echo "Claude Desktop is running — quit it first"; exit 1; }
stamp=$(date +%Y%m%d-%H%M%S)
dest="$HOME/claude-backups/claude-desktop-backup-$stamp"
[ -e "$dest" ] && { echo "Backup dir already exists: $dest"; exit 1; }
mkdir -p "$dest"; chmod 700 "$HOME/claude-backups" "$dest"
rsync -a "$appdata/" "$dest/" || { echo "Backup failed"; exit 1; }
[ -e "$appdata.old" ] && { echo "Claude.old already exists — resolve first"; exit 1; }
# If the rename fails, the profile is still live — do NOT touch its Keychain key
mv "$appdata" "$appdata.old" || { echo "Rename failed — Keychain left untouched"; exit 1; }
# Old Electron encryption key — recreated on next launch for the new login
# (loop: multiple past logins can leave multiple items; delete every copy)
while security delete-generic-password -s "Claude Safe Storage" >/dev/null 2>&1; do :; done
```

Windows (DPAPI keys are per-Windows-user; renaming the profile suffices):

```powershell
$appdata = Join-Path $env:APPDATA "Claude"
if (-not (Test-Path -LiteralPath $appdata)) { "Claude Desktop not installed - skip"; return }
if (Get-Process -Name "Claude","claude" -ErrorAction SilentlyContinue) {
  throw "Claude Desktop is running - quit it first"
}
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$dest = Join-Path $env:USERPROFILE "claude-backups\claude-desktop-backup-$stamp"
if (Test-Path -LiteralPath $dest) { throw "Backup dir already exists: $dest" }
New-Item -ItemType Directory -Force -Path $dest | Out-Null
icacls (Split-Path $dest) /inheritance:r /grant:r "${env:USERNAME}:(OI)(CI)F" | Out-Null
robocopy $appdata $dest /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /MT:8 /NFL /NDL /NP
if ($LASTEXITCODE -gt 7) { throw "Backup failed: $LASTEXITCODE" }
if (Test-Path -LiteralPath "$appdata.old") { throw "Claude.old already exists - resolve first" }
Rename-Item -LiteralPath $appdata -NewName "Claude.old" -ErrorAction Stop
```

Then have the user relaunch Claude Desktop and log in with the new account.
After confirming the new login works, restore the MCP config:

macOS:

```bash
old_cfg="$HOME/Library/Application Support/Claude.old/claude_desktop_config.json"
new_cfg="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
if [ -f "$old_cfg" ]; then
  cp -p "$old_cfg" "$new_cfg" || { echo "MCP config restore failed"; exit 1; }
fi
```

Windows:

```powershell
$oldCfg = Join-Path $env:APPDATA "Claude.old\claude_desktop_config.json"
$newCfg = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
if (Test-Path -LiteralPath $oldCfg) {
  Copy-Item -LiteralPath $oldCfg -Destination $newCfg -Force -ErrorAction Stop
}
```

`Claude.old` and the desktop backup follow the same retention rule as step 9:
they hold the old claude.ai session and are deleted only after the user
confirms the new identity works. Note: the desktop session stores are binary
(SQLite/LevelDB), so the step-7 text leak scan does not cover them — identity
removal here is achieved by never migrating the session stores, not by
scanning.

## Other machine state (optional, mention to the user)

Outside `.claude`, Claude Code and Claude Desktop may keep further traces.
Not part of the default workflow; offer them as optional cleanup only if
present (relevant mainly for a "restore to never-installed" goal):

- macOS: `~/Library/Caches/claude-cli-nodejs` (MCP/tool logs, caches)
- Windows: `%LOCALAPPDATA%\claude-cli-nodejs` (if present)
- Native-install binaries/versions (e.g. `~/.local/share/claude`,
  `~/.local/bin/claude`) — reinstall artifacts, safe to keep.
- macOS, Claude Desktop residue beyond `Application Support/Claude`: the
  app's bundle id can leave entries under `~/Library/Caches`,
  `~/Library/Preferences`, `~/Library/WebKit`, `~/Library/HTTPStorages`,
  and `~/Library/Saved Application State`. Bundle ids and directory names
  change between app versions, so the flow is always search → confirm the
  entry belongs to Claude / Anthropic → quit Claude Desktop → delete.
  Never batch-delete on the name match alone — other Anthropic tools,
  development SDKs, or third-party integrations may legitimately match:

  ```bash
  find ~/Library \( -iname "*claude*" -o -iname "*anthropic*" \) 2>/dev/null
  ```

- Browser claude.ai session: logging into claude.ai in Safari/Chrome/Edge
  is a separate login that no filesystem step here touches. For a complete
  account switch, have the user log out of claude.ai in the browser or
  clear the site's cookies/site data; claude.ai Settings can also log out
  all active sessions for the account remotely.

## Reporting

Report the detected platform, exact paths, and pass/fail for each stage:
preconditions (sessions closed, disk space, PowerShell 7+ on Windows, legacy
Desktop backups found/relocated or absent), backup created (folder name with
its to-the-second timestamp) and verified (per-item + count check), identity
regenerated, migration exit code, `.claude.json` merge result, `settings.json`
merge result (step 6b, including any stripped secrets), identity-leak
scan result, post-migration verification, and — when the desktop app is
installed — the Claude Desktop stage (in-app switch or file-level reset,
backup name, MCP config restored). If any step is blocked by file locks or
access denied, stop and explain the current state instead of forcing
deletion. Always end the migration report by listing what still holds the old
identity (`.claude.old`, `Claude.old`, backups, old Keychain items on macOS)
and that deletion waits for the user's explicit confirmation. Also list the
stores this workflow deliberately did NOT touch unless asked (browser
claude.ai session, MCP OAuth credentials) so the user knows where a
lingering login can come from.

## References

- Claude Code IAM: https://docs.anthropic.com/en/docs/claude-code/iam
- Claude Code CLI reference: https://docs.anthropic.com/en/docs/claude-code/cli-reference
- Claude Code MCP: https://docs.anthropic.com/en/docs/claude-code/mcp
- Installing Claude for Desktop: https://support.anthropic.com/en/articles/10065433-installing-claude-for-desktop
- Log out of all active sessions: https://support.anthropic.com/en/articles/10310342-how-do-i-log-out-of-all-active-sessions

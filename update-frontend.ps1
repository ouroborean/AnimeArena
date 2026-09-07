<#
  update-frontend.ps1 - prep a new Nexus concept's assets for the Cloudflare Pages deploy.

  A Nexus concept goes live across two surfaces:
    - BACKEND (VM, NOT this script): the Discord bot's /add-nexus + /confirm-nexus create
      "bucket data/<path>.dat" and the nexus_meta.json grouping row on the server. Run those first;
      the server picks them up within ~30s (no restart).
    - FRONTEND (this script): the web client resolves each concept's NAME + PORTRAIT from
      char_index.json by path_name. This adds that row + preps the art, then optionally publishes.

  It edits SOURCE files only - deploy/ and discord-bot/data/ are regenerated build artifacts
  (deploy/ by build-pages-deploy.ps1, the bot snapshot by deploy-bot.ps1), never hand-edited:
    1. Find concept folders under assets/images/ (or the ones you name) that have a <path>prof.png
       but no char_index row yet.
    2. Guard each prof image: if it is really a WebP saved with a .png extension, re-encode to a
       true PNG with ffmpeg (else the <img> can fail to render).
    3. Merge the char_index row into webclient/app/char_index.json - format-preserving + idempotent.
       (NEVER regenerates via extract_char_index.gd: that dumps only bucket_handler.all_chars and
        would clobber every hand-added disk-only Nexus concept.)
    4. Bump ASSET_VERSION in webclient/app/app.js (the art edge-cache buster).
    5. With -Deploy: run deploy.ps1 -SkipServer (build-pages-deploy.ps1 + wrangler pages deploy).

  Naming convention (confirmed against supersaiyangoku / dragonforcewendy):
    folder "Awakened Shigaraki"  ->  path    "awakenedshigaraki"   (lowercase, non-alphanumerics dropped)
                                     name    "Awakened Shigaraki"  (folder verbatim)
                                     default "Awakened Shigaraki/awakenedshigarakiprof.png"

  Universe grouping is SERVER-driven; char_index carries only name+portrait, so a concept in an
  EXISTING universe needs no app.js edit. A brand-NEW universe still needs its key added by hand to
  NEXUS_UNIVERSE_KEYS in webclient/app/app.js (+ discord-bot/cogs/nexus.py) - this script can't guess
  a universe from a folder name, so it just prints a reminder.

  Usage:
    .\update-frontend.ps1                       # scan for new concept folders, confirm, prep
    .\update-frontend.ps1 "Awakened Shigaraki"  # prep exactly this folder (no scan, no prompt)
    .\update-frontend.ps1 -Deploy               # prep, then publish to Cloudflare Pages
    .\update-frontend.ps1 -Yes                  # in scan mode, don't prompt to confirm the picks
    .\update-frontend.ps1 -NoBump               # skip the ASSET_VERSION bump
    .\update-frontend.ps1 -DryRun               # show what would change; write nothing
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
  [string[]]$Characters,
  [switch]$Deploy,
  [switch]$Yes,
  [switch]$NoBump,
  [switch]$DryRun,
  [string]$AssetVersion = (Get-Date -Format "yyyy-MM-dd")
)
$ErrorActionPreference = "Stop"
$root      = $PSScriptRoot
$imgRoot   = Join-Path $root "assets\images"
$charIdx   = Join-Path $root "webclient\app\char_index.json"
$appJs     = Join-Path $root "webclient\app\app.js"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)   # UTF-8 without BOM, matches the existing files

function Section($m) { Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Die($m)     { Write-Host "`nFAILED: $m" -ForegroundColor Red; exit 1 }

# path_name from a display/folder name: lowercase, keep only a-z0-9 (matches the existing keys).
function ConvertTo-PathName([string]$folder) { return ($folder.ToLowerInvariant() -replace '[^a-z0-9]', '') }

# True if the char_index raw text already has a top-level "<path>": key. Read-only; never reformats.
function Test-CharIndexHas([string]$raw, [string]$path) {
  return ($raw -match ('"' + [regex]::Escape($path) + '"\s*:'))
}

# Folder names under assets/images that git sees as NEW (untracked "??" or added "A") - i.e. a concept
# you just dropped in, versus the committed roster. This keeps no-arg scan mode from surfacing the whole
# character roster (playable folders are tracked; a fresh concept folder is not). Read-only git call.
function Get-NewImageFolders {
  $out = New-Object System.Collections.Generic.HashSet[string]
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $out }
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $lines = & git -C $root status --porcelain
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prev
  if ($code -ne 0) { return $out }
  foreach ($ln in $lines) {
    if ($ln -match '^\s*(\?\?|A|AM)\s+"?(.+?)"?\s*$') {
      $p = ($matches[2] -replace '/', '\')
      if ($p -match '^assets\\images\\([^\\]+)') { [void]$out.Add($matches[1]) }
    }
  }
  return $out
}

# If $file is a WebP saved with a .png extension, re-encode it to a real PNG (ffmpeg: temp then swap).
# Real PNG magic = 89 50 4E 47; WebP = "RIFF"(52 49 46 46) then 4 size bytes then "WEBP"(57 45 42 50).
function Repair-ProfileImage([string]$file) {
  $fs = [System.IO.File]::OpenRead($file)
  try { $b = New-Object byte[] 12; $n = $fs.Read($b, 0, 12) } finally { $fs.Dispose() }
  if ($n -lt 12) { Write-Warning "  ! $file is under 12 bytes - leaving as-is"; return }
  $isPng = ($b[0] -eq 0x89 -and $b[1] -eq 0x50 -and $b[2] -eq 0x4E -and $b[3] -eq 0x47)
  if ($isPng) { return }
  $isWebp = ($b[0] -eq 0x52 -and $b[1] -eq 0x49 -and $b[2] -eq 0x46 -and $b[3] -eq 0x46 -and
             $b[8] -eq 0x57 -and $b[9] -eq 0x45 -and $b[10] -eq 0x42 -and $b[11] -eq 0x50)
  if (-not $isWebp) { Write-Warning "  ! $file is neither PNG nor WebP (odd magic bytes) - leaving as-is"; return }
  Write-Host "  ! $file is a WebP saved as .png - re-encoding to real PNG" -ForegroundColor Yellow
  if ($DryRun) { Write-Host "    (dry run: would run ffmpeg)" -ForegroundColor DarkGray; return }
  if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Die "ffmpeg is not on PATH but '$file' must be re-encoded. Install ffmpeg, or replace the file with a real PNG."
  }
  $tmp = [System.IO.Path]::ChangeExtension($file, ".__reencode.png")
  & ffmpeg -y -v error -i $file $tmp
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tmp)) {
    if (Test-Path $tmp) { Remove-Item -Force $tmp }
    Die "ffmpeg failed to re-encode $file (exit $LASTEXITCODE)"
  }
  Move-Item -Force $tmp $file
  Write-Host "  ~ re-encoded WebP -> PNG: $file" -ForegroundColor Green
}

# Append "<path>": {"default": "<folder>/<path>prof.png", "name": "<folder>"} to the single-line
# char_index.json, preserving its exact format (", "/": " separators, default-first, no trailing
# newline) and insertion order. Returns $true if it wrote a new row, $false if the key already existed.
function Add-CharIndexRow([string]$jsonPath, [string]$path, [string]$folder) {
  $raw = [System.IO.File]::ReadAllText($jsonPath)
  if (Test-CharIndexHas $raw $path) { return $false }
  $entry = '"' + $path + '": {"default": "' + $folder + '/' + $path + 'prof.png", "name": "' + $folder + '"}'
  $t = $raw.TrimEnd()
  if (-not $t.EndsWith('}')) { Die "char_index.json is not a JSON object (no closing brace): $jsonPath" }
  $body = $t.Substring(0, $t.Length - 1).TrimEnd()          # drop the outer closing brace
  if ($body.EndsWith('{')) { $new = $body + $entry + '}' }   # was an empty object {}
  else                     { $new = $body + ', ' + $entry + '}' }
  if (-not $DryRun) { [System.IO.File]::WriteAllText($jsonPath, $new, $utf8NoBom) }  # no BOM, no trailing newline
  return $true
}

# ---------------------------------------------------------------------------------------------------
Section "update-frontend  (ASSET_VERSION target: $AssetVersion$(if($DryRun){'  [DRY RUN]'}))"
if (-not (Test-Path $charIdx)) { Die "not found: $charIdx" }
if (-not (Test-Path $appJs))   { Die "not found: $appJs" }
if (-not (Test-Path $imgRoot)) { Die "not found: $imgRoot" }

# ---- 1. decide which concept folders to process ----
$srcRaw  = [System.IO.File]::ReadAllText($charIdx)
$targets = @()

if ($Characters) {
  foreach ($name in $Characters) {
    $folder = Split-Path $name -Leaf                 # tolerate a full path or a bare folder name
    $dir    = Join-Path $imgRoot $folder
    if (-not (Test-Path $dir)) { Die "no such asset folder: assets\images\$folder" }
    $targets += [pscustomobject]@{ Folder = $folder; Path = (ConvertTo-PathName $folder); Dir = $dir }
  }
} else {
  Section "Scanning assets\images for NEW (git-untracked) concept folders missing from char_index"
  $new = Get-NewImageFolders
  if ($new.Count -eq 0) {
    Write-Host "  git reports no new/untracked folders under assets\images." -ForegroundColor DarkGray
    Write-Host "  If the folder you added is already committed, name it explicitly:" -ForegroundColor DarkGray
    Write-Host "    .\update-frontend.ps1 `"Your Folder Name`"" -ForegroundColor Gray
  }
  foreach ($folderName in ($new | Sort-Object)) {
    $dir = Join-Path $imgRoot $folderName
    if (-not (Test-Path $dir -PathType Container)) { continue }
    $path = ConvertTo-PathName $folderName
    if (-not $path) { continue }
    if (-not (Test-Path (Join-Path $dir ($path + "prof.png")))) {
      Write-Host "  ? '$folderName' is new but has no ${path}prof.png - skipping (check the image name)." -ForegroundColor DarkYellow
      continue
    }
    if (Test-CharIndexHas $srcRaw $path) { continue }   # already indexed (e.g. Goku/Wendy from a prior run)
    $targets += [pscustomobject]@{ Folder = $folderName; Path = $path; Dir = $dir }
  }
}

if (-not $targets -or $targets.Count -eq 0) {
  Write-Host "  char_index already covers every folder that has a <path>prof.png - nothing to add." -ForegroundColor Green
  if (-not $Deploy) { exit 0 }
} else {
  Write-Host "`n  char_index rows to add:" -ForegroundColor Yellow
  foreach ($t in $targets) {
    Write-Host ("    {0,-24} name='{1}'  default='{2}/{0}prof.png'" -f $t.Path, $t.Folder, $t.Folder)
  }
  if (-not $Characters -and -not $Yes -and -not $DryRun) {
    $ans = Read-Host "`n  Proceed with these? (y/N)"
    if ($ans -notmatch '^[Yy]') { Die "aborted by user" }
  }
}

# ---- 2 + 3. per target: WebP guard + char_index merge ----
$changed = $false
foreach ($t in $targets) {
  Section ("Concept: {0}  ->  {1}" -f $t.Folder, $t.Path)
  $prof = Join-Path $t.Dir ($t.Path + "prof.png")
  if (-not (Test-Path $prof)) { Die "missing profile image: $prof  (expected <path>prof.png in the folder)" }
  Repair-ProfileImage $prof
  if (Add-CharIndexRow $charIdx $t.Path $t.Folder) {
    Write-Host ("  + char_index += {0}" -f $t.Path) -ForegroundColor Green
    $changed = $true
  } else {
    Write-Host ("  = char_index already has {0} (skip)" -f $t.Path) -ForegroundColor DarkGray
  }
}

# ---- 4. bump ASSET_VERSION (art cache-buster) in the SOURCE app.js ----
if ($changed -and -not $NoBump) {
  Section "Bumping ASSET_VERSION"
  $appRaw = [System.IO.File]::ReadAllText($appJs)
  $rx = 'const ASSET_VERSION = "\d{4}-\d{2}-\d{2}";'
  if ($appRaw -notmatch $rx) { Die "couldn't find the ASSET_VERSION line in $appJs" }
  $appNew = [regex]::Replace($appRaw, $rx, ('const ASSET_VERSION = "' + $AssetVersion + '";'))
  if ($appNew -ne $appRaw) {
    if (-not $DryRun) { [System.IO.File]::WriteAllText($appJs, $appNew, $utf8NoBom) }
    Write-Host "  ~ ASSET_VERSION -> $AssetVersion" -ForegroundColor Green
  } else {
    Write-Host "  = ASSET_VERSION already $AssetVersion" -ForegroundColor DarkGray
  }
} elseif ($NoBump) {
  Write-Host "  (ASSET_VERSION bump skipped: -NoBump)" -ForegroundColor DarkGray
}

# ---- 5. verify + (optionally) publish ----
if (-not $DryRun -and $changed) {
  Section "Verify"
  $verifyRaw = [System.IO.File]::ReadAllText($charIdx)
  try { $null = $verifyRaw | ConvertFrom-Json } catch { Die "char_index.json is no longer valid JSON after the edit: $($_.Exception.Message)" }
  foreach ($t in $targets) {
    if (-not (Test-CharIndexHas $verifyRaw $t.Path)) { Die "post-check: '$($t.Path)' not found in char_index.json" }
  }
  Write-Host "  char_index.json is valid JSON and contains every target row." -ForegroundColor Green
}

if ($targets.Count -gt 0) {
  Write-Host "`n  Reminder: this touched SOURCE only. deploy/ regenerates via build-pages-deploy.ps1;" -ForegroundColor DarkGray
  Write-Host "  the Discord bot's char_index snapshot refreshes on the next .\deploy-bot.ps1." -ForegroundColor DarkGray
  Write-Host "  New universe? add its key to NEXUS_UNIVERSE_KEYS in webclient/app/app.js by hand (existing ones are fine)." -ForegroundColor DarkGray
}

if ($Deploy -and -not $DryRun) {
  Section "Publishing to Cloudflare Pages (deploy.ps1 -SkipServer)"
  & (Join-Path $root "deploy.ps1") -SkipServer
  if ($LASTEXITCODE -ne 0) { Die "deploy.ps1 exited $LASTEXITCODE" }
} elseif (-not $DryRun) {
  Write-Host "`n  Source prepped. To publish the web client:" -ForegroundColor Yellow
  Write-Host "    .\deploy.ps1 -SkipServer          # assemble deploy/ + wrangler pages deploy" -ForegroundColor Gray
  Write-Host "    (or re-run this as: .\update-frontend.ps1 -Deploy)" -ForegroundColor Gray
}
Section "Done"

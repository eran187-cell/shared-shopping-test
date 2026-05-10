# =====================================================================
# Deploy: copy the test build to the production repo with the
# environment-specific transformations applied. Designed to run from
# anywhere; reads tools/prod.config.json for paths and Firebase config.
#
# Pre-flight (one-time):
#   1. git clone https://github.com/eran187-cell/shared-shopping.git C:\Users\topel\shared-shopping
#   2. Edit prod.config.json → fill in firebaseConfig from Firebase Console
#
# Run:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy_to_prod.ps1
#   add -DryRun to see what would change without writing
#   add -NoCommit to apply changes but skip git commit/push
# =====================================================================
param(
  [string]$Config   = 'C:\Users\topel\shared-shopping-test\tools\prod.config.json',
  [string]$TestRepo = 'C:\Users\topel\shared-shopping-test',
  [switch]$DryRun,
  [switch]$NoCommit
)
$ErrorActionPreference = 'Stop'
$OutputEncoding = [Text.Encoding]::UTF8
[Console]::OutputEncoding = [Text.Encoding]::UTF8

function Step($s) { Write-Host ">>> $s" -ForegroundColor Cyan }
function Ok($s)   { Write-Host "    ✓ $s"  -ForegroundColor Green }
function Warn($s) { Write-Host "    ! $s"  -ForegroundColor Yellow }

# ── 0) Sanity checks ─────────────────────────────────────────────────
if (-not (Test-Path $Config)) { throw "Config file not found at $Config" }
$cfg = Get-Content $Config -Raw -Encoding UTF8 | ConvertFrom-Json
$prod = $cfg.prodRepoPath
$fb   = $cfg.firebaseConfig
$ver  = if ($cfg.appVersion) { $cfg.appVersion } else { '1.0' }
$mail = if ($cfg.supportEmail) { $cfg.supportEmail } else { 'comigo2022@gmail.com' }

if ($fb.apiKey -eq 'REPLACE_ME') { throw 'Firebase config has placeholder values. Fill in prod.config.json from Firebase Console first.' }
if (-not (Test-Path $prod)) {
  throw "Production repo not found at $prod.`n   Clone first: git clone https://github.com/eran187-cell/shared-shopping.git `"$prod`""
}
if (-not (Test-Path (Join-Path $TestRepo 'index.html'))) { throw "Test repo invalid: $TestRepo" }

Step 'Loading test build…'
$html = Get-Content (Join-Path $TestRepo 'index.html') -Raw -Encoding UTF8
$origLen = $html.Length
Ok "Read index.html ($origLen chars)"

# ── 1) Replace the FB_CFG block ───────────────────────────────────────
Step 'Rewriting FB_CFG with production credentials…'
$newFb = @"
const FB_CFG={
  apiKey:'$($fb.apiKey)',
  authDomain:'$($fb.authDomain)',
  databaseURL:'$($fb.databaseURL)',
  projectId:'$($fb.projectId)',
  storageBucket:'$($fb.storageBucket)',
  messagingSenderId:'$($fb.messagingSenderId)',
  appId:'$($fb.appId)'
};
"@
$html = [regex]::Replace($html, '(?s)const FB_CFG=\{[^}]*\};', { param($m) $newFb })
Ok 'FB_CFG replaced'

# ── 2) APP_VERSION ────────────────────────────────────────────────────
$html = [regex]::Replace($html, "const APP_VERSION='[^']*';", "const APP_VERSION='$ver';")
Ok "APP_VERSION → '$ver'"

# ── 3) Strip TEST badges everywhere ───────────────────────────────────
Step 'Removing TEST badges and indicators…'
$html = $html -replace '<title>Shared Shopping \(TEST\)</title>', '<title>Shared Shopping</title>'
$html = $html -replace 'content="Shared Shopping TEST"', 'content="Shared Shopping"'
# Remove the entire test banner: comment + wrapper div + the script block
# that wires the reset button. All three reference testResetBtn / testBanner
# and would crash in prod if any one is left orphaned.
$html = [regex]::Replace($html, '(?s)<!--\s*TEST environment[^>]*-->\s*<div id="testBanner"[^>]*>.*?</div>\s*<script>[^<]*testResetBtn[^<]*</script>', '')
# Safety net: drop any remaining standalone script that references testResetBtn
$html = [regex]::Replace($html, '(?s)<script>[^<]*testResetBtn[^<]*</script>', '')
# Splash TEST badge (the small red TEST chip + the inline TEST in name)
$html = [regex]::Replace($html, '\s*<span style="background:#e74c3c;color:#fff;font-size:10px;font-weight:700;letter-spacing:1px;padding:3px 10px;border-radius:0 0 8px 8px">TEST</span>', '')
$html = $html -replace '<div class="sp-name">Shared Shopping <span style="color:#e74c3c">TEST</span></div>', '<div class="sp-name">Shared Shopping</div>'
$html = [regex]::Replace($html, '<div class="sp-sub">[^<]*</div>', '')
# Admin dashboard TEST tags
$html = $html -replace '<span class="admin-test-tag">TEST</span>', ''
$html = $html -replace 'Shared Shopping <span style="color:#e74c3c;font-size:14px">TEST</span>', 'Shared Shopping'
Ok 'TEST indicators removed'

# ── 4) Replace support email if customised ────────────────────────────
$html = [regex]::Replace($html, "comigo2022@gmail\.com", $mail)

# ── 5) Write index.html ───────────────────────────────────────────────
$dstHtml = Join-Path $prod 'index.html'
if ($DryRun) { Warn "DRY-RUN: would write index.html" }
else {
  Set-Content -Path $dstHtml -Value $html -Encoding UTF8
  Ok "Wrote $dstHtml"
}

# ── 6) Static assets — copy verbatim ──────────────────────────────────
Step 'Copying static assets (manifest, products catalog, icon)…'
@('products_by_department.json','icon.svg') | ForEach-Object {
  $src = Join-Path $TestRepo $_
  $dst = Join-Path $prod $_
  if (Test-Path $src) {
    if ($DryRun) { Warn "DRY-RUN: would copy $_" }
    else { Copy-Item $src $dst -Force; Ok "Copied $_" }
  }
}

# ── 7) manifest.json — copy + drop TEST naming ────────────────────────
$mfSrc = Join-Path $TestRepo 'manifest.json'
$mfDst = Join-Path $prod 'manifest.json'
if (Test-Path $mfSrc) {
  $mfTxt = Get-Content $mfSrc -Raw -Encoding UTF8
  $mfTxt = $mfTxt -replace '"name":\s*"Shared Shopping TEST"', '"name": "Shared Shopping"'
  $mfTxt = $mfTxt -replace '"short_name":\s*"SS TEST"', '"short_name": "Shared Shopping"'
  if ($DryRun) { Warn 'DRY-RUN: would write manifest.json' }
  else { Set-Content -Path $mfDst -Value $mfTxt -Encoding UTF8; Ok 'Wrote manifest.json' }
}

# ── 8) sw.js — bump production cache ──────────────────────────────────
Step 'Bumping production sw.js cache…'
$swSrc = Join-Path $TestRepo 'sw.js'
$swDst = Join-Path $prod 'sw.js'
$nextCache = 'ss-v1'
if (Test-Path $swDst) {
  $prevTxt = Get-Content $swDst -Raw -Encoding UTF8
  if ($prevTxt -match "const CACHE='ss-v(\d+)'") {
    $nextCache = "ss-v$([int]$matches[1] + 1)"
  }
}
$swTxt = Get-Content $swSrc -Raw -Encoding UTF8
$swTxt = [regex]::Replace($swTxt, "const CACHE='[^']*';", "const CACHE='$nextCache';")
if ($DryRun) { Warn "DRY-RUN: would set CACHE='$nextCache'" }
else { Set-Content -Path $swDst -Value $swTxt -Encoding UTF8; Ok "CACHE → '$nextCache'" }

# ── 9) Git commit + push ──────────────────────────────────────────────
if ($DryRun -or $NoCommit) {
  Warn 'Skipping git commit/push'
} else {
  Step 'Committing + pushing to production repo…'
  Push-Location $prod
  try {
    & git add -A
    & git -c user.email=eran187@users.noreply.github.com -c user.name=eran187-cell commit -m "Deploy from test → $nextCache (app v$ver)"
    & git push
    Ok "Pushed. GitHub Pages will go live within ~1-2 minutes."
  } finally { Pop-Location }
}

Write-Host ''
Write-Host "✓ Done. Production cache: $nextCache, app version: $ver" -ForegroundColor Green
Write-Host "  URL: https://eran187-cell.github.io/shared-shopping/"

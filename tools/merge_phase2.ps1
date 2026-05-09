# =====================================================================
# Merges Phase-2 additions into the main catalog with heavy cleanup.
# - Drops items with weight/volume suffixes (e.g. "200ג", "275מל", "1.5ל")
# - Drops items with brand prefixes / dotted abbreviations
# - Drops compound product names (containing +, /, double-quotes)
# - Drops noise tokens that mark cleaning / cosmetics products
# - Caps each department to MaxPerDept items (default 100)
# =====================================================================
param(
  [int]$MaxPerDept = 100,
  [string]$AdditionsFile = 'C:\Users\topel\shared-shopping-test\tools\_phase2_additions.json',
  [string]$CatalogFile   = 'C:\Users\topel\shared-shopping-test\products_by_department.json',
  [string]$OutFile       = 'C:\Users\topel\shared-shopping-test\products_by_department.json'
)
$ErrorActionPreference = 'Stop'
$OutputEncoding = [Text.Encoding]::UTF8
[Console]::OutputEncoding = [Text.Encoding]::UTF8

function IsClean([string]$n) {
  if ($n.Length -lt 3 -or $n.Length -gt 25) { return $false }
  # contains digits → almost always a packaging variant
  if ($n -match '\d') { return $false }
  # quotes / parens / pluses / slashes / asterisks → packaging or compound
  if ($n -match '["()/+*]') { return $false }
  # dotted abbreviations like "ב.מטעמים", "מ.ריח", "דאו.דאב", "גב.נפולאון"
  if ($n -match '\.') { return $false }
  # ends with unit/abbrev
  if ($n -match '\b(גר|מל|ק"ג|קג|יח|שק|מחיר|תפזורת)$') { return $false }
  # known brand / packaging tokens
  $blockedTokens = @(
    'סנפרוסט','דורות','דאב','דאו','סני','שופרסל','פיניש','האגיס','פמפרס',
    'דנונה','גלידל','אולטרסול','אריאל','פרסיל','קולגייט','אקווה',
    'מ.ריח','מ.ריח','ב.מטעמים','גב.','משקה','מסיר','מסטר','מנקה',
    'בריזר','חליטת','ופלים','גלידל','מארז','מארזפטריות',
    'תפזורת','במשקל','במגשית','מגשית','אורגנית במשקל','אורגני במשקל'
  )
  foreach ($t in $blockedTokens) { if ($n.Contains($t)) { return $false } }
  return $true
}

Write-Host '>>> Loading files…' -ForegroundColor Cyan
$addJson = Get-Content -Path $AdditionsFile -Raw -Encoding UTF8 | ConvertFrom-Json
$catJson = Get-Content -Path $CatalogFile   -Raw -Encoding UTF8 | ConvertFrom-Json

# Find dept objects (longest property name in each)
function GetDeptObj($obj) {
  foreach ($p in $obj.PSObject.Properties) { if ($p.Name.Length -eq 6) { return $p.Value } }
  return $null
}
$addDepts = GetDeptObj $addJson
$catDepts = GetDeptObj $catJson
if (-not $addDepts -or -not $catDepts) { throw 'Could not locate the מחלקות object' }

# Build set of all existing names across all depts (cross-dept dedup)
$existingAll = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($p in $catDepts.PSObject.Properties) {
  foreach ($n in $p.Value) { [void]$existingAll.Add($n) }
}
$beforeCount = $existingAll.Count
Write-Host ("    Existing items: " + $beforeCount)

# Process each addition dept
$summary = New-Object 'System.Collections.Specialized.OrderedDictionary'
foreach ($p in $addDepts.PSObject.Properties) {
  $deptName = $p.Name
  $rawAdds  = @($p.Value)
  # Filter
  $clean = New-Object 'System.Collections.Generic.List[string]'
  foreach ($n in $rawAdds) {
    if (-not (IsClean $n)) { continue }
    if ($existingAll.Contains($n)) { continue }
    [void]$clean.Add($n)
  }
  # Sort + cap
  $sorted = $clean | Sort-Object -Unique
  if ($sorted.Count -gt $MaxPerDept) { $sorted = $sorted[0..($MaxPerDept-1)] }
  $summary[$deptName] = @{ raw = $rawAdds.Count; clean = $sorted.Count; items = $sorted }
}

# Merge into catalog (preserve existing order; append new at end of each dept)
$totalAdded = 0
foreach ($k in $summary.Keys) {
  $items = $summary[$k].items
  if ($items.Count -eq 0) { continue }
  # Find dept in catDepts; if missing, add
  $existing = $catDepts.PSObject.Properties[$k]
  if ($null -eq $existing) {
    $catDepts | Add-Member -NotePropertyName $k -NotePropertyValue @($items)
  } else {
    $merged = @($existing.Value) + @($items)
    $catDepts.PSObject.Properties.Remove($k)
    $catDepts | Add-Member -NotePropertyName $k -NotePropertyValue $merged
  }
  foreach ($n in $items) { [void]$existingAll.Add($n) }
  $totalAdded += $items.Count
}

# Update meta
foreach ($p in $catJson.PSObject.Properties) {
  if ($p.Name.Length -eq 3) {
    $p.Value.PSObject.Properties.Remove('מספר_מוצרים') | Out-Null
    $p.Value | Add-Member -NotePropertyName 'מספר_מוצרים' -NotePropertyValue $existingAll.Count -Force
    $p.Value.PSObject.Properties.Remove('עדכון_אחרון') | Out-Null
    $p.Value | Add-Member -NotePropertyName 'עדכון_אחרון' -NotePropertyValue (Get-Date -Format 'yyyy-MM-dd') -Force
    $p.Value.PSObject.Properties.Remove('גרסה') | Out-Null
    $p.Value | Add-Member -NotePropertyName 'גרסה' -NotePropertyValue '1.2' -Force
    break
  }
}

# Save (pretty JSON)
$out = $catJson | ConvertTo-Json -Depth 6
Set-Content -Path $OutFile -Value $out -Encoding UTF8

Write-Host ''
Write-Host '>>> Done.' -ForegroundColor Green
Write-Host ('    Items before:   ' + $beforeCount)
Write-Host ('    Items added:    ' + $totalAdded)
Write-Host ('    Items after:    ' + ($beforeCount + $totalAdded))
Write-Host ''
Write-Host 'Per-department breakdown:' -ForegroundColor Yellow
foreach ($k in $summary.Keys) {
  $s = $summary[$k]
  Write-Host ("  {0,-30} raw {1,4}  →  added {2,3}" -f $k, $s.raw, $s.clean)
}

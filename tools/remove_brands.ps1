$ErrorActionPreference = 'Stop'
$OutputEncoding = [Text.Encoding]::UTF8
[Console]::OutputEncoding = [Text.Encoding]::UTF8

# Brand names to strip from the catalog. These are products identified
# primarily by a brand label that have a generic equivalent in the catalog
# (e.g. "שמפו דאב" → drop, the generic "שמפו" stays).
# Israeli pharma names that crossed over into generic use (אקמול, נורופן,
# אספירין, אופטלגין) are intentionally kept.
$brands = @(
    # מוצרי חלב
    'אקטיביה','דנונה','מעדן אקטימל',
    'גבינה צהובה עמק','גבינה צהובה גלבוע','גבינה צהובה ברסלר',
    'יוגורט יוגוצ''ה','יוגורט מולר','מעדן פיראוס',
    # דגנים — cereal brand
    'ציריוס',
    # קפה ותה
    'קפה עלית','קפה ג''ייקובס','קפה לוואצה','קפסולות נספרסו','תה ויסוצקי',
    # שתייה קרה
    'מי עדן','נביעות','מי נביעות',
    'קוקה קולה','קוקה קולה וניל',
    'ספרייט','ספרייט זירו',
    'פנטה','פנטה ענבים',
    'שוופס','שוופס לימון','שוופס מנדרינה','שוופס טוניק',
    'פיוז טי',
    'רד בול','מונסטר','XL',
    'בירה גולדסטאר','בירה מכבי','בירה קרלסברג','בירה היינקן',
    # ממתקים — international + Israeli candy brands
    'שוקולד פרה','שוקולד עלית','שוקולד לינדט','שוקולד טובלרון','שוקולד מילקה','שוקולד פררו',
    'פסק זמן','מקופלת','קלין סוויט',
    'קינדר בואנו','קינדר ביצה','קינדר שוקולד',
    'סניקרס','מארס','טוויקס','קיט קט','באונטי','ניוטל','קיין',
    'מסטיק טראידנט','מסטיק אורביט',
    'גלידת בן אנד ג''ריס','גלידת שטראוס',
    'אוראו','עוגיות אוראו','עוגיות לוטוס','ממרח לוטוס',
    'פרינגלס','דוריטוס','צ''יטוס','טפוצ''יפס',
    # תינוקות
    'חיתולי האגיס','חיתולי פמפרס','חיתולי בייבי דריי','חיתולי בייבי סיטר',
    'מטרנה','סימילק',
    # טואלטיקה
    'שמפו הד אנד שולדרס','שמפו פנטן','שמפו דאב','ג''ל רחצה דאב',
    'משחת שיניים קולגייט','משחת שיניים סנסודיין',
    'מי פה ליסטרין','קרם ידיים ניוטרוגינה',
    # ניקיון
    'סבון כלים פיירי','סבון כלים סנוואיט','מנקה רצפות סוד',
    'אבקת כביסה אריאל','אבקת כביסה פרסיל','טבליות פיניש',
    # Phase-2 leftovers detectable by exact name
    'מים מיסלריים','סומרסבי מנגו ליים','בריזר לימון בקבוק','חליטת לימון ג''ינג''ר','חליטת קמומיל+נענע',
    'דאב רול און','דאב רול און מלפפון','דאו.דאב סטיק מלפפון'
)
$blockSet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($b in $brands) { [void]$blockSet.Add($b) }

$path = 'C:\Users\topel\shared-shopping-test\products_by_department.json'
$raw = Get-Content -Path $path -Raw -Encoding UTF8
$obj = $raw | ConvertFrom-Json
$mahla = $null
foreach ($p in $obj.PSObject.Properties) { if ($p.Name.Length -eq 6) { $mahla = $p.Value; break } }
if (-not $mahla) { throw 'מחלקות section not found' }

$removed = New-Object 'System.Collections.Generic.List[string]'
$totalBefore = 0; $totalAfter = 0
foreach ($p in @($mahla.PSObject.Properties)) {
    $items = @($p.Value)
    $totalBefore += $items.Count
    $kept = New-Object 'System.Collections.Generic.List[string]'
    foreach ($it in $items) {
        if ($blockSet.Contains($it)) { $removed.Add($p.Name + ' / ' + $it) }
        else { $kept.Add($it) }
    }
    $totalAfter += $kept.Count
    $mahla.PSObject.Properties.Remove($p.Name) | Out-Null
    $mahla | Add-Member -NotePropertyName $p.Name -NotePropertyValue $kept.ToArray()
}

# Update meta
foreach ($p in $obj.PSObject.Properties) {
    if ($p.Name.Length -eq 3) {
        $p.Value.PSObject.Properties.Remove('מספר_מוצרים') | Out-Null
        $p.Value | Add-Member -NotePropertyName 'מספר_מוצרים' -NotePropertyValue $totalAfter -Force
        $p.Value.PSObject.Properties.Remove('עדכון_אחרון') | Out-Null
        $p.Value | Add-Member -NotePropertyName 'עדכון_אחרון' -NotePropertyValue (Get-Date -Format 'yyyy-MM-dd') -Force
        $p.Value.PSObject.Properties.Remove('גרסה') | Out-Null
        $p.Value | Add-Member -NotePropertyName 'גרסה' -NotePropertyValue '1.3' -Force
        break
    }
}

$out = $obj | ConvertTo-Json -Depth 6
Set-Content -Path $path -Value $out -Encoding UTF8

Write-Host '>>> Done.' -ForegroundColor Green
Write-Host ('    Items before:   ' + $totalBefore)
Write-Host ('    Items removed:  ' + $removed.Count)
Write-Host ('    Items after:    ' + $totalAfter)
Write-Host ''
Write-Host 'Removed:' -ForegroundColor Yellow
foreach ($r in $removed) { Write-Host ('  - ' + $r) }

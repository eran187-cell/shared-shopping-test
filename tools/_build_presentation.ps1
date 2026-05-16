$ErrorActionPreference='Stop'
$OutputEncoding=[Text.Encoding]::UTF8
[Console]::OutputEncoding=[Text.Encoding]::UTF8

$outPath='C:\Users\topel\shared-shopping-presentation.docx'
$jsonPath='C:\Users\topel\shared-shopping-test\tools\_presentation_content.json'

Write-Host '>>> Loading content from JSON...' -ForegroundColor Cyan
$raw=Get-Content -Path $jsonPath -Raw -Encoding UTF8
$c=$raw | ConvertFrom-Json

Write-Host '>>> Launching Word...' -ForegroundColor Cyan
$word=New-Object -ComObject Word.Application
$word.Visible=$false
$word.DisplayAlerts=0
$doc=$word.Documents.Add()
$sel=$word.Selection

# Constants
$wdAlignCenter=1
$wdAlignRight=2
$wdAlignJustify=3
$wdFormatDocumentDefault=16
$wdStory=6

# Default font
$sel.Font.NameAscii='Arial'
$sel.Font.NameOther='Arial'
$sel.Font.Size=12

function Set-RTL { param($a=$wdAlignRight)
    $sel.ParagraphFormat.ReadingOrder=1
    $sel.RtlPara() | Out-Null
    $sel.ParagraphFormat.Alignment=$a
}

function Write-H1 { param([string]$text)
    $sel.Style=$doc.Styles.Item('Heading 1')
    Set-RTL
    $sel.Font.Size=22
    $sel.Font.Bold=$true
    $sel.Font.Color=2105376
    $sel.TypeText($text)
    $sel.TypeParagraph()
    $sel.Style=$doc.Styles.Item('Normal')
    $sel.Font.Size=12
    $sel.Font.Bold=$false
    $sel.Font.Color=0
}

function Write-H2 { param([string]$text)
    $sel.Style=$doc.Styles.Item('Heading 2')
    Set-RTL
    $sel.Font.Size=16
    $sel.Font.Bold=$true
    $sel.Font.Color=46125
    $sel.TypeText($text)
    $sel.TypeParagraph()
    $sel.Style=$doc.Styles.Item('Normal')
    $sel.Font.Size=12
    $sel.Font.Bold=$false
    $sel.Font.Color=0
}

function Write-P { param([string]$text)
    if(-not $text -or $text.Length -eq 0){return}
    Set-RTL $wdAlignJustify
    $sel.Font.Size=12
    $sel.Font.Bold=$false
    $sel.TypeText($text)
    $sel.TypeParagraph()
}

function Write-Bullet { param([string]$text)
    Set-RTL
    $sel.Font.Size=12
    $sel.Range.ListFormat.ApplyBulletDefault()
    $sel.TypeText($text)
    $sel.TypeParagraph()
}

function Write-Space {
    Set-RTL
    $sel.TypeParagraph()
}

function Write-PB { $sel.InsertNewPage() }

function Write-Center { param([string]$text,[int]$size=12,[bool]$bold=$false,[int]$color=0)
    Set-RTL $wdAlignCenter
    $sel.Font.Size=$size
    $sel.Font.Bold=$bold
    $sel.Font.Color=$color
    $sel.TypeText($text)
    $sel.TypeParagraph()
    $sel.Font.Bold=$false
    $sel.Font.Color=0
}

# ════════════════ PAGE 1 - COVER ════════════════
Write-Host '>>> Page 1: cover...' -ForegroundColor Cyan
for($i=0;$i -lt 5;$i++){Write-Space}
Write-Center $c.cover.logoLine 36 $true 46125
Write-Space
Write-Center $c.cover.title 26 $true 0
Write-Space
Write-Space
Write-Center $c.cover.subtitle 14 $false 7895160
for($i=0;$i -lt 6;$i++){Write-Space}
Write-Center $c.cover.date 13 $true 7895160
Write-Space
Write-Center $c.cover.url 11 $false 5469486
Write-PB

# ════════════════ PAGE 2 - INTRO ════════════════
Write-Host '>>> Page 2: intro...' -ForegroundColor Cyan
Write-H1 $c.intro.h1
Write-Space
foreach($s in $c.intro.sections){
    Write-H2 $s.h2
    Write-P $s.p
}
Write-PB

# ════════════════ PAGES 3-7 - PHASES ════════════════
$pageCount=3
$phaseIdx=0
$totalPhases=$c.phases.Count
$phasesPerPage=2
foreach($ph in $c.phases){
    if($phaseIdx -eq 0){
        Write-Host (">>> Page $pageCount`: phases starting...") -ForegroundColor Cyan
        Write-H1 'שלבי הפיתוח'
        Write-Space
    }
    Write-H2 $ph.h2
    if($ph.p){Write-P $ph.p}
    foreach($b in $ph.bullets){Write-Bullet $b}
    Write-Space
    $phaseIdx++
    if($phaseIdx % $phasesPerPage -eq 0 -and $phaseIdx -lt $totalPhases){
        Write-PB
        $pageCount++
    }
}
Write-PB

# ════════════════ PAGE 8 - KPI TABLE ════════════════
Write-Host '>>> Page 8: KPI table...' -ForegroundColor Cyan
Write-H1 $c.kpis.h1
Write-Space
Write-P $c.kpis.intro
Write-Space

# Table
Set-RTL
$rows=$c.kpis.rows
$rowCount=$rows.Count
$range=$sel.Range
$table=$doc.Tables.Add($range,$rowCount,2)
$table.Borders.Enable=$true
$table.Range.Font.NameAscii='Arial'
$table.Range.Font.Size=12
for($r=0;$r -lt $rowCount;$r++){
    $row=$table.Rows.Item($r+1)
    for($col=0;$col -lt 2;$col++){
        $cell=$row.Cells.Item($col+1)
        $cell.Range.Text=$rows[$r][$col]
        $cell.Range.ParagraphFormat.ReadingOrder=1
        if($r -eq 0){
            $cell.Range.Font.Bold=$true
            $cell.Shading.BackgroundPatternColor=15269604
        }
    }
}
$table.Rows.Item(1).HeadingFormat=$true
$sel.EndKey($wdStory) | Out-Null
Write-Space
Write-Space
Write-P $c.kpis.footer
Write-PB

# ════════════════ PAGE 9 - FEATURES ════════════════
Write-Host '>>> Page 9: features...' -ForegroundColor Cyan
Write-H1 $c.features.h1
Write-Space
foreach($f in $c.features.items){
    Write-H2 $f.h2
    Write-P $f.p
}
Write-PB

# ════════════════ PAGE 10 - CONCLUSION ════════════════
Write-Host '>>> Page 10: conclusion...' -ForegroundColor Cyan
Write-H1 $c.conclusion.h1
Write-Space
foreach($s in $c.conclusion.sections){
    Write-H2 $s.h2
    if($s.p){Write-P $s.p}
    if($s.bullets){
        foreach($b in $s.bullets){Write-Bullet $b}
    }
}
Write-Space
Write-Space
Write-Center $c.conclusion.thanks 18 $true 46125
Write-Space
Write-Center $c.conclusion.contact 11 $false 7895160

# Save
Write-Host '>>> Saving...' -ForegroundColor Cyan
$doc.SaveAs([ref]$outPath,[ref]$wdFormatDocumentDefault)
$doc.Close()
$word.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($sel) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($doc) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
[GC]::Collect()

$size=(Get-Item $outPath).Length/1KB
Write-Host (">>> Done. File saved to: $outPath") -ForegroundColor Green
Write-Host ("    Size: {0:N1} KB" -f $size)

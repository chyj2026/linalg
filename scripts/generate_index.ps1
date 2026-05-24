# scripts/generate_index.ps1
# Regenerates index.qmd from manifest.json so every non-duplicate session
# has a working link (published or stub). Run after generate_stubs.ps1
# whenever the manifest changes.

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Manifest = Get-Content (Join-Path $RepoRoot 'manifest.json') -Raw | ConvertFrom-Json

$active = $Manifest.sessions | Where-Object { $_.status -ne 'excluded_duplicate' }
$published = @($active | Where-Object { $_.status -eq 'published' })

$sessionCount = $active.Count
$publishedCount = $published.Count

# Newly Added section: most-recently dated published lessons (up to 4)
$recent = $published | Sort-Object date -Descending | Select-Object -First 4
$recentCards = ($recent | ForEach-Object {
@"
<article class="lesson-card is-new">
  <div class="lesson-card-meta"><span>$($_.date) — $($_.session)</span><span>Published</span></div>
  <h3><a href="lessons/$($_.id).html">$($_.title_en -replace '"', '&quot;')</a></h3>
  <p>$($_.lead -replace '"', '&quot;')</p>
</article>
"@
}) -join "`n"

# Full lesson library: every active session, chronological
$rows = ($active | Sort-Object date, session | ForEach-Object {
    $date = if ($_.date) { $_.date } else { '—' }
    $session = if ($_.session) { $_.session } else { '—' }
    $title = $_.title_en -replace '"', '&quot;'
    $confidence = $_.date_confidence
    $marker = ''
    if ($confidence -eq 'medium')  { $marker = ' <sup title="medium-confidence date">⚠</sup>' }
    if ($confidence -eq 'unknown') { $marker = ' <sup title="unknown date — inferred">⚠</sup>' }
    $badge = if ($_.status -eq 'published') { ' <span class="mini-badge">Published</span>' } else { ' <span class="mini-badge" style="background:#9ca3af;">Stub</span>' }
    "<tr><td>$date$marker</td><td>$session</td><td><a href=`"lessons/$($_.id).html`">$title</a>$badge</td></tr>"
}) -join "`n"

$content = @"
---
title: "Linear Algebra Notes"
---

``````{=html}
<section class="course-hero">
  <div>
    <p class="lesson-kicker">Rigorous Saturday-class notes</p>
    <h1>Linear Algebra Notes</h1>
    <p>Distilled lecture notes — symbol dictionaries, theorems formally stated, two independent derivations for key results, verification audits, and the full transcript preserved as appendix. Embedded video for every session.</p>
  </div>
  <div class="course-stats" aria-label="Course statistics">
    <div><strong>$sessionCount</strong><span>sessions</span></div>
    <div><strong>$publishedCount</strong><span>lessons distilled</span></div>
  </div>
</section>
``````

::: {.callout-note}
**Course scope.** Repository name says *linalg*, but the underlying class covers a broader math arc: modular arithmetic & Fermat–Euler (Sep 2025) → complex exponentials & Euler's formula (Sep 2025) → conic sections (Oct 2025) → polynomial graphing & rational functions (Nov 2025) → series & ζ-function (Dec 2025 – Jan 2026) → linear algebra & eigentheory (Jan – May 2026). Topic tags reflect this; chronological order preserves the spiral teaching pattern.
:::

::: {.callout-warning collapse="true"}
## Page status legend

- **Distilled** — full rigor: symbol dictionary, two independent derivations, verification audit, fragility summary, hand-authored figures, semantically-aligned key frames extracted from video.
- **Stub** — auto-generated from `manifest.json` metadata: title, lead, topic tags, key theorems list, embedded video, full verbatim transcript appendix. Browsable, searchable, video-playable; but proofs and audits are pending. See [extract_frames.sh](https://github.com/chyj2026/linalg/blob/main/scripts/extract_frames.sh) and [generate_stubs.ps1](https://github.com/chyj2026/linalg/blob/main/scripts/generate_stubs.ps1) for the toolchain.
:::

## Newly distilled lessons

``````{=html}
<div class="lesson-grid">
$recentCards
</div>
``````

## Full Lesson Library

``````{=html}
<div class="lesson-table-wrap">
<table class="lesson-index-table">
  <thead><tr><th>Date</th><th>Session</th><th>Topic</th></tr></thead>
  <tbody>
$rows
  </tbody>
</table>
</div>
``````

::: {.callout-tip collapse="true"}
## Excluded duplicate
``Saturday04062026afternoon1.txt`` is byte-identical to ``Saturday0404morning.txt`` — a mislabeled upload. It is recorded in ``manifest.json`` with ``status: "excluded_duplicate"`` and is not shown in the index above. The Drive video ID and verbatim transcript are preserved in case the duplicate is informative.

⚠ markers on dates indicate ``date_confidence: medium`` or ``unknown`` — verify against Drive ``createdTime`` or recording metadata before relying on them.
:::
"@

$indexPath = Join-Path $RepoRoot 'index.qmd'
$content | Set-Content -Path $indexPath -Encoding utf8

Write-Host "wrote index.qmd:"
Write-Host "  sessions  = $sessionCount"
Write-Host "  published = $publishedCount"
Write-Host "  stubs     = $($sessionCount - $publishedCount)"

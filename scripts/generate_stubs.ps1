# scripts/generate_stubs.ps1
# Generates a stub .qmd file in lessons/ for every session in manifest.json
# whose status is "draft" and whose lesson file does not already exist.
#
# Each stub contains: front-matter, lead paragraph, topics, key theorems list,
# embedded Drive video (or GitHub Release if available), and the full
# verbatim transcript appended in a .txt code fence.
#
# Stubs are clearly marked as "auto-generated from manifest metadata, pending
# full rigor distillation". They render and are browsable, but do NOT have
# symbol dictionaries, two-derivation proofs, verification audits, etc.

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Manifest = Get-Content (Join-Path $RepoRoot 'manifest.json') -Raw | ConvertFrom-Json

$generated = 0
$skipped   = 0

foreach ($s in $Manifest.sessions) {
    if ($s.status -ne 'draft') {
        $skipped++
        continue
    }

    $qmdPath = Join-Path $RepoRoot "lessons\$($s.id).qmd"
    if (Test-Path $qmdPath) {
        $skipped++
        continue
    }

    $transcriptPath = Join-Path $RepoRoot $s.transcript
    if (-not (Test-Path $transcriptPath)) {
        Write-Warning "transcript missing for $($s.id): $transcriptPath"
        continue
    }

    # Pick the best available video embed
    if ($s.video_github_release) {
        $videoSrc = $s.video_github_release
        $videoCaption = "hosted on <a href=`"https://github.com/chyj2026/linalg/releases`" target=`"_blank`">GitHub Release</a>"
    } else {
        $videoSrc = $null  # iframe to Drive embed
    }

    $topicsLine = if ($s.topics) { '[' + ($s.topics -join ', ') + ']' } else { '[]' }
    $title      = if ($s.title_en) { $s.title_en } else { "Untitled session ($($s.date))" }
    $lead       = if ($s.lead) { $s.lead } else { "*Lead pending — distill from transcript.*" }
    $date       = if ($s.date)    { $s.date } else { '1900-01-01' }
    $session    = if ($s.session) { $s.session } else { 'unspecified' }
    $notes      = if ($s.notes)   { $s.notes } else { $null }
    $homework   = if ($s.homework){ $s.homework } else { $null }

    # Build theorems section
    $theoremsBlock = if ($s.key_theorems -and $s.key_theorems.Count -gt 0) {
        $list = ($s.key_theorems | ForEach-Object { "- $_" }) -join "`n"
        "## Key theorems and identities (from the session)`n`n$list`n"
    } else {
        ""
    }

    $homeworkBlock = if ($homework) {
        @"
## Homework given

::: {.callout-important}
$homework
:::

"@
    } else { "" }

    $notesBlock = if ($notes) {
        @"
::: {.callout-note collapse="true"}
## Session notes (transcript artefacts and meta-content)

$notes
:::

"@
    } else { "" }

    # Build video block
    $videoBlock = if ($videoSrc) {
@"
``````{=html}
<video controls width="100%" preload="metadata" style="border-radius:6px;">
  <source src="$videoSrc" type="video/mp4">
  Your browser does not support HTML5 video.
</video>
<p style="text-align:center;font-size:0.85em;color:#6b7280;margin-top:0.4em;">
  $videoCaption · also viewable in <a href="$($s.video_view)" target="_blank">Google Drive</a>
</p>
``````
"@
    } else {
@"
``````{=html}
<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden;">
  <iframe src="$($s.video_embed)"
          style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: 0;"
          allow="autoplay" allowfullscreen></iframe>
</div>
<p style="text-align:center;font-size:0.9em;color:#6b7280;margin-top:0.4em;">
  Streaming from Google Drive (no GitHub Release yet) · <a href="$($s.video_view)" target="_blank">Open in Drive ↗</a>
</p>
``````
"@
    }

    # Title-block front-matter + body
    $body = @"
---
title: "$($title -replace '"', '\"')"
date: $date
session: $session
topics: $topicsLine
---

::: {.callout-warning}
**Auto-generated stub.** This page renders the session metadata + embedded video + verbatim transcript appendix from `manifest.json`. It has *not* yet been distilled under the rigor protocol (symbol dictionary, two independent derivations, verification audit, fragility summary, hand-authored figures). The two reference lessons that show the target format: [2026-03-07-LVS](2026-03-07-LVS.html) and [2026-03-07-cramer-review](2026-03-07-cramer-review.html).
:::

## Lead

$lead

$theoremsBlock
$homeworkBlock
$notesBlock
## Lecture video

$videoBlock

## Full transcript

::: {.callout-note collapse="true"}
## Verbatim transcript of the session

``````{.txt}
"@

    # Write body, append transcript, close fences
    $body | Set-Content -Path $qmdPath -Encoding utf8 -NoNewline

    # Append transcript verbatim
    $transcript = Get-Content $transcriptPath -Raw
    Add-Content -Path $qmdPath -Value "`n$transcript" -Encoding utf8 -NoNewline

    # Close fences
    Add-Content -Path $qmdPath -Value "`n``````" -Encoding utf8 -NoNewline
    Add-Content -Path $qmdPath -Value "`n:::" -Encoding utf8 -NoNewline

    $generated++
    Write-Host "  generated: lessons\$($s.id).qmd"
}

Write-Host ""
Write-Host "done. generated $generated, skipped $skipped"

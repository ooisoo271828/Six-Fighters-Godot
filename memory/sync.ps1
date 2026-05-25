#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sync Claude Code memory files from system location to project directory.
.DESCRIPTION
    Dynamically locates Claude Code's auto-memory directory for this project,
    then copies all memory files to the project's memory/ folder for version control.

    Works on any machine: computes the slug from the project path automatically.
#>

# ---- Compute project slug ----
# Claude Code generates the slug by replacing every non-alphanumeric
# character in the project root path with "-".
# Example: D:\Vibe Coding\Six-Fighters-Godot → D--Vibe-Coding-Six-Fighters-Godot
$ProjectRoot = (Get-Item $PSScriptRoot).Parent.FullName
$Slug = [regex]::Replace($ProjectRoot, '[^a-zA-Z0-9]', '-')

$Source = Join-Path $HOME ".claude" "projects" $Slug "memory"
$Target = $PSScriptRoot

if (-not (Test-Path $Source)) {
    Write-Warning "[memory-sync] Source not found: $Source"
    Write-Warning "[memory-sync] Try running: ls '$HOME/.claude/projects/' to find the correct slug"
    exit 0
}

$copied = 0
foreach ($file in Get-ChildItem -Path $Source -File) {
    Copy-Item -Path $file.FullName -Destination $Target -Force
    $copied++
}

Write-Output "[memory-sync] Copied $copied files from $Source to $Target"

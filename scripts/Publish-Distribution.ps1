param(
    [ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')][string]$Repository = 'SJSK0517/usage-tray-codex',
    [ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')][string]$SourceRepository = 'SJSK0517/lab-codex',
    [ValidatePattern('^usage-tray-v\d+\.\d+\.\d+$')][string]$Tag = 'usage-tray-v1.4.5'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
foreach ($command in @('git', 'gh')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { throw "$command is required. Install Git and GitHub CLI, then run gh auth login." }
}
function Invoke-Gh {
    $result = & gh @args
    if ($LASTEXITCODE -ne 0) { throw 'GitHub command failed. Check gh auth login and repository permissions.' }
    return $result
}
function Invoke-Git {
    & git @args
    if ($LASTEXITCODE -ne 0) { throw 'Git command failed. Remote history was not force-overwritten.' }
}

$account = (Invoke-Gh api user | ConvertFrom-Json).login
$release = Invoke-Gh api "repos/$SourceRepository/releases/tags/$Tag" | ConvertFrom-Json
if ($release.draft -or $release.prerelease) { throw 'Only a published stable source release can be distributed.' }
if (-not (Select-String -Path README.md -SimpleMatch "/$Repository/releases/tag/$Tag" -Quiet)) { throw 'Update the README version and download links before publishing.' }
$names = @('UsageTray-Setup-win-x64.exe', 'UsageTray-Setup-win-arm64.exe', 'UsageTray-Setup-win-x64.exe.sha256', 'UsageTray-Setup-win-arm64.exe.sha256', 'SHA256SUMS.txt')
foreach ($name in $names) { if (-not ($release.assets | Where-Object name -eq $name)) { throw "Source release is missing $name" } }

$cache = Join-Path ([IO.Path]::GetTempPath()) ("UsageTrayRelease-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $cache | Out-Null
try {
    foreach ($name in $names) { Invoke-Gh release download $Tag --repo $SourceRepository --pattern $name --dir $cache }
    $sums = @{}
    foreach ($line in Get-Content (Join-Path $cache 'SHA256SUMS.txt')) {
        if ($line -notmatch '^([a-fA-F0-9]{64})  (UsageTray-Setup-win-(?:x64|arm64)\.exe)$') { throw 'Invalid checksum manifest.' }
        if ($sums.ContainsKey($Matches[2])) { throw 'Duplicate checksum manifest entry.' }
        $sums[$Matches[2]] = $Matches[1].ToLowerInvariant()
    }
    if ($sums.Count -ne 2) { throw 'Both installer checksums are required.' }
    foreach ($name in $names) {
        $asset = $release.assets | Where-Object name -eq $name
        if ((Get-Item (Join-Path $cache $name)).Length -ne $asset.size) { throw "Source asset size mismatch: $name" }
    }
    foreach ($name in @('UsageTray-Setup-win-x64.exe', 'UsageTray-Setup-win-arm64.exe')) {
        $actual = (Get-FileHash (Join-Path $cache $name) -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $sums[$name]) { throw "Installer checksum mismatch: $name" }
        $single = (Get-Content (Join-Path $cache "$name.sha256") -Raw).Trim()
        if ($single -ne "$actual  $name") { throw "Individual checksum mismatch: $name" }
    }

    $targetText = & gh api "repos/$Repository" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Invoke-Gh repo create $Repository --public --description 'Windows 11 taskbar widget for shared Codex and ChatGPT Work plan usage. Installer downloads and documentation.'
        $targetText = Invoke-Gh api "repos/$Repository"
    }
    $target = $targetText | ConvertFrom-Json
    if ($target.private) { throw 'The distribution repository must be public. Existing visibility was not changed.' }
    $existing = & gh release view $Tag --repo $Repository --json isDraft 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'This release tag already exists in the target. It was not overwritten; inspect it before resuming.' }

    if (-not (Test-Path (Join-Path $root '.git'))) { Invoke-Git init -b main }
    $expectedRemote = "https://github.com/$Repository.git"
    $remote = & git remote get-url origin 2>$null
    if ($LASTEXITCODE -ne 0) { Invoke-Git remote add origin $expectedRemote }
    elseif ($remote -ne $expectedRemote) { throw 'Unexpected origin remote; it was not changed.' }
    Invoke-Git add README.md RELEASE-NOTES.md PUBLISHING.md .gitignore assets scripts
    & git diff --cached --quiet
    if ($LASTEXITCODE -eq 1) { Invoke-Git -c "user.name=$account" -c "user.email=$account@users.noreply.github.com" commit -m "docs: distribute $Tag installers and usage guide" }
    elseif ($LASTEXITCODE -ne 0) { throw 'Could not inspect staged documentation changes.' }
    Invoke-Git push origin HEAD:refs/heads/main

    Invoke-Gh release create $Tag --repo $Repository --target main --draft --title "Usage Tray $($Tag -replace '^usage-tray-', '')" --notes-file RELEASE-NOTES.md
    $paths = @($names | ForEach-Object { Join-Path $cache $_ })
    Invoke-Gh release upload $Tag @paths --repo $Repository
    $uploaded = @(Invoke-Gh api "repos/$Repository/releases?per_page=100" | ConvertFrom-Json) | Where-Object tag_name -eq $Tag
    if (@($uploaded).Count -ne 1) { throw 'Could not identify the draft release.' }
    foreach ($name in $names) {
        $asset = $uploaded.assets | Where-Object name -eq $name
        $local = Join-Path $cache $name
        $digest = (Get-FileHash $local -Algorithm SHA256).Hash.ToLowerInvariant()
        if (-not $asset -or $asset.size -ne (Get-Item $local).Length) { throw "Uploaded asset missing or size mismatch: $name" }
        if ($asset.digest) {
            if ($asset.digest -ne "sha256:$digest") { throw "Uploaded checksum mismatch: $name" }
        }
        else {
            $verify = Join-Path $cache 'uploaded'
            New-Item -ItemType Directory -Force $verify | Out-Null
            Invoke-Gh release download $Tag --repo $Repository --pattern $name --dir $verify
            if ((Get-FileHash (Join-Path $verify $name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $digest) { throw "Uploaded checksum mismatch: $name" }
        }
    }
    Invoke-Gh release edit $Tag --repo $Repository --draft=false --latest
    Write-Host "Published: https://github.com/$Repository/releases/tag/$Tag"
}
finally {
    Remove-Item $cache -Recurse -Force -ErrorAction SilentlyContinue
}

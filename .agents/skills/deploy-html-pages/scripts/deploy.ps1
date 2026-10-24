<#
.SYNOPSIS
    Deploy HTML web apps directly to GitHub Pages via GitHub REST API without requiring git or gh CLI.

.PARAMETER TargetPath
    Path to the HTML file or folder containing web assets (Default: ./index.html or current folder).

.PARAMETER RepoName
    Name of the GitHub repository. (Default: current directory name).

.PARAMETER RepoDescription
    Description for the repository.

.PARAMETER Token
    GitHub Personal Access Token (PAT). If omitted, reads from $env:GITHUB_TOKEN or .env.

.EXAMPLE
    .\deploy.ps1 -TargetPath .\index.html -RepoName "my-cool-app"
#>

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]$TargetPath = "",

    [Parameter(Position = 1)]
    [string]$RepoName = "",

    [Parameter()]
    [string]$RepoDescription = "Web application created and deployed with Antigravity",

    [Parameter()]
    [string]$Token = ""
)

$ErrorActionPreference = "Stop"

# Output helpers
function Write-Step ($message) {
    Write-Host "`n[*] $message" -ForegroundColor Cyan
}

function Write-Success ($message) {
    Write-Host "[+] $message" -ForegroundColor Green
}

function Write-WarningMsg ($message) {
    Write-Host "[!] $message" -ForegroundColor Yellow
}

function Write-ErrorMsg ($message) {
    Write-Host "[-] $message" -ForegroundColor Red
}

# --- Step 1: Resolve GitHub Token ---
Write-Step "Resolving GitHub Personal Access Token (PAT)..."

if (-not $Token) {
    if ($env:GITHUB_TOKEN) {
        $Token = $env:GITHUB_TOKEN.Trim()
    } elseif (Test-Path ".env") {
        Get-Content ".env" | ForEach-Object {
            $line = $_.Trim()
            if ($line -match '^GITHUB_TOKEN\s*=\s*(.+)$') {
                $Token = $matches[1].Trim().Trim('"').Trim("'")
            }
        }
    }
}

if (-not $Token) {
    Write-ErrorMsg "GitHub Token not found!"
    Write-Host "Please provide a GitHub Personal Access Token (PAT) with 'repo' scope." -ForegroundColor Yellow
    Write-Host "You can do one of the following:" -ForegroundColor Gray
    Write-Host '  1. Set environment variable: $env:GITHUB_TOKEN = "your_pat_token"' -ForegroundColor Gray
    Write-Host '  2. Create a .env file with: GITHUB_TOKEN=your_pat_token' -ForegroundColor Gray
    Write-Host '  3. Pass as argument: .\deploy.ps1 -Token "your_pat_token"' -ForegroundColor Gray
    Write-Host "`nGenerate token here: https://github.com/settings/tokens/new?scopes=repo" -ForegroundColor Cyan
    exit 1
}

$headers = @{
    "Authorization"        = "Bearer $Token"
    "Accept"               = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
    "User-Agent"           = "Antigravity-Deployer"
}

# --- Step 2: Authenticate and get user details ---
Write-Step "Authenticating with GitHub REST API..."
try {
    $user = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers -Method Get
    $username = $user.login
    Write-Success "Authenticated as: $username ($($user.name))"
} catch {
    Write-ErrorMsg "Authentication failed. Check if your GITHUB_TOKEN is valid and has 'repo' permissions."
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# --- Step 3: Resolve Target Path and Repository Name ---
if (-not $TargetPath) {
    if (Test-Path "index.html") {
        $TargetPath = "index.html"
    } else {
        $TargetPath = (Get-Location).Path
    }
}

$resolvedPath = Resolve-Path $TargetPath
$isDir = (Get-Item $resolvedPath) -is [System.IO.DirectoryInfo]

if (-not $RepoName) {
    if ($isDir) {
        $RepoName = (Get-Item $resolvedPath).Name
    } else {
        $RepoName = (Get-Location).Name
    }
}

# Sanitize repository name (replace spaces and special characters with hyphens)
$RepoName = ($RepoName -replace '[^a-zA-Z0-9_\.-]', '-').ToLower()

Write-Host "  -> Target: $resolvedPath" -ForegroundColor Gray
Write-Host "  -> Target Repository: $username/$RepoName" -ForegroundColor Gray

# --- Step 4: Ensure Public Repository Exists ---
Write-Step "Checking repository status ($username/$RepoName)..."
$repoExists = $false
try {
    $existingRepo = Invoke-RestMethod -Uri "https://api.github.com/repos/$username/$RepoName" -Headers $headers -Method Get
    $repoExists = $true
    Write-Success "Repository already exists ($($existingRepo.html_url))"
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 404) {
        Write-Host "Repository does not exist. Creating new public repository..." -ForegroundColor Yellow
        $createBody = @{
            name        = $RepoName
            description = $RepoDescription
            private     = $false
            auto_init   = $true
        } | ConvertTo-Json

        $newRepo = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Headers $headers -Method Post -Body $createBody
        Write-Success "Created public repository: $($newRepo.html_url)"
        Start-Sleep -Seconds 2
        $repoExists = $true
    } else {
        Write-ErrorMsg "Failed to verify repository: $($_.Exception.Message)"
        exit 1
    }
}

# --- Step 5: Gather Files to Upload ---
$filesToUpload = @()

if (-not $isDir) {
    # Single file mode (e.g. index.html)
    $filesToUpload += [PSCustomObject]@{
        FullName = (Get-Item $resolvedPath).FullName
        RelPath  = "index.html"
    }
} else {
    # Directory mode
    $ignoredPatterns = @(".git", ".env", "node_modules", ".gemini", "deploy.ps1")
    $allFiles = Get-ChildItem -Path $resolvedPath -Recurse -File
    foreach ($file in $allFiles) {
        $skip = $false
        foreach ($pattern in $ignoredPatterns) {
            if ($file.FullName -like "*\$pattern*" -or $file.Name -eq $pattern) {
                $skip = $true
                break
            }
        }
        if (-not $skip) {
            $rel = $file.FullName.Substring($resolvedPath.Path.Length).TrimStart("\").Replace("\", "/")
            $filesToUpload += [PSCustomObject]@{
                FullName = $file.FullName
                RelPath  = $rel
            }
        }
    }
}

if ($filesToUpload.Count -eq 0) {
    Write-ErrorMsg "No files found to deploy!"
    exit 1
}

Write-Step "Uploading $($filesToUpload.Count) file(s) to branch 'main'..."

foreach ($f in $filesToUpload) {
    $filePath = $f.RelPath
    Write-Host "  Uploading: $filePath ... " -NoNewline -ForegroundColor Gray

    # Check if file already exists in repo to obtain its sha (required for update)
    $existingSha = $null
    try {
        $fileInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$username/$RepoName/contents/$filePath?ref=main" -Headers $headers -Method Get
        $existingSha = $fileInfo.sha
    } catch {
        # 404 means file doesn't exist yet, which is normal for new files
    }

    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    $b64 = [Convert]::ToBase64String($bytes)

    $putBody = @{
        message = "Deploy web app via Antigravity deploy-html-pages: $filePath"
        content = $b64
        branch  = "main"
    }
    if ($existingSha) {
        $putBody["sha"] = $existingSha
    }

    $jsonBody = $putBody | ConvertTo-Json -Compress

    try {
        $putResp = Invoke-RestMethod -Uri "https://api.github.com/repos/$username/$RepoName/contents/$filePath" -Headers $headers -Method Put -Body $jsonBody
        Write-Host "OK" -ForegroundColor Green
    } catch {
        Write-Host "FAILED" -ForegroundColor Red
        Write-ErrorMsg "Could not upload $filePath : $($_.Exception.Message)"
    }
}

# --- Step 6: Enable GitHub Pages ---
Write-Step "Configuring GitHub Pages..."

$pagesConfigured = $false
try {
    $pagesInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$username/$RepoName/pages" -Headers $headers -Method Get
    $pagesConfigured = $true
    Write-Success "GitHub Pages already configured."
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 404) {
        Write-Host "Enabling GitHub Pages on main branch..." -ForegroundColor Yellow
        $pagesBody = @{
            source = @{
                branch = "main"
                path   = "/"
            }
        } | ConvertTo-Json

        try {
            $pagesInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$username/$RepoName/pages" -Headers $headers -Method Post -Body $pagesBody
            $pagesConfigured = $true
            Write-Success "GitHub Pages enabled successfully!"
        } catch {
            Write-WarningMsg "Pages activation call returned: $($_.Exception.Message)"
        }
    }
}

# --- Step 7: Construct Live URL & Output Report ---
$liveUrl = "https://$($username.ToLower()).github.io/$RepoName/"

Write-Host "`n========================================================" -ForegroundColor Magenta
Write-Host "  DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Magenta
Write-Host "  Live URL       : $liveUrl" -ForegroundColor Cyan
Write-Host "  GitHub Repo    : https://github.com/$username/$RepoName" -ForegroundColor White
Write-Host "  Pages Settings : https://github.com/$username/$RepoName/settings/pages" -ForegroundColor Gray
Write-Host "========================================================" -ForegroundColor Magenta
Write-Host "`nNote: If this is the very first deployment, GitHub Pages may take 1-2 minutes" -ForegroundColor Yellow
Write-Host "      to finish building and become accessible at the live URL above." -ForegroundColor Yellow

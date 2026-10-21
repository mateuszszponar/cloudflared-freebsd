<#
.SYNOPSIS
  Builds cloudflared for FreeBSD (e.g. OPNsense) from an official Cloudflare release tag.

.DESCRIPTION
  1. Clones the given tag of github.com/cloudflare/cloudflared.
  2. Applies three small FreeBSD compatibility fixes (see README.md).
  3. Cross-compiles a static FreeBSD binary into .\dist\ and writes SHA256SUMS.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\build.ps1 -Version 2026.10.3
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$Arch = "amd64"
)

$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$src  = Join-Path $root "build\cloudflared-$Version"
$dist = Join-Path $root "dist"
$name = "cloudflared-freebsd-$Arch"
$out  = Join-Path $dist $name

function Write-NoBom([string]$Path, [string]$Text) {
    # Go build tags must be on the very first line, so never write a UTF-8 BOM.
    [IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

# --- 1. Fresh checkout of the official tag -----------------------------------
if (Test-Path $src) { Remove-Item -Recurse -Force $src }
New-Item -ItemType Directory -Force (Split-Path $src) | Out-Null
git clone --quiet --branch $Version --depth 1 https://github.com/cloudflare/cloudflared $src
if ($LASTEXITCODE -ne 0) { throw "git clone failed for tag $Version" }
$commit = (git -C $src rev-parse --short HEAD).Trim()
Write-Host "Source: cloudflare/cloudflared@$Version ($commit)"

# --- 2. FreeBSD compatibility fixes ------------------------------------------
# 2a. The Unix network collector works on FreeBSD as-is; enable it.
$net  = Join-Path $src "diagnostic\network\collector_unix.go"
$text = [IO.File]::ReadAllText($net)
if ($text -notmatch "go:build[^\n]*freebsd") {
    Write-NoBom $net ($text -replace "//go:build darwin \|\| linux", "//go:build darwin || linux || freebsd")
    Write-Host "Fix: enabled diagnostic/network/collector_unix.go for freebsd"
}

# 2b. System information collector is not implemented for FreeBSD -> stub.
$diag = Join-Path $src "diagnostic"
if (-not [bool](Select-String -Path (Join-Path $diag "*.go") -Pattern "go:build.*freebsd" -Quiet)) {
    Write-NoBom (Join-Path $diag "system_collector_freebsd.go") @'
//go:build freebsd

package diagnostic

import (
	"context"
	"errors"
)

type SystemCollectorImpl struct {
	version string
}

func NewSystemCollectorImpl(version string) *SystemCollectorImpl {
	return &SystemCollectorImpl{version}
}

func (collector *SystemCollectorImpl) Collect(ctx context.Context) (*SystemInformation, error) {
	return nil, errors.New("system information collection is not supported on FreeBSD")
}
'@
    Write-Host "Fix: added diagnostic/system_collector_freebsd.go (stub)"
}

# 2c. Token file creation: reuse the existing Unix implementation.
$cmd = Join-Path $src "cmd\cloudflared"
if (-not [bool](Select-String -Path (Join-Path $cmd "*.go") -Pattern "go:build.*freebsd" -Quiet)) {
    Write-NoBom (Join-Path $cmd "freebsd_token.go") @'
//go:build freebsd

package main

func createTokenFile(path string) error {
	return createTokenFileUnix(path)
}
'@
    Write-Host "Fix: added cmd/cloudflared/freebsd_token.go"
}

# --- 3. Build -----------------------------------------------------------------
New-Item -ItemType Directory -Force $dist | Out-Null
$date = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$env:GOOS = "freebsd"; $env:GOARCH = $Arch; $env:CGO_ENABLED = "0"
Push-Location $src
try {
    go build -trimpath -ldflags "-s -w -X main.Version=$Version -X main.BuildTime=$date" -o $out ./cmd/cloudflared
    if ($LASTEXITCODE -ne 0) { throw "go build failed" }
}
finally {
    Pop-Location
    Remove-Item Env:GOOS, Env:GOARCH, Env:CGO_ENABLED -ErrorAction SilentlyContinue
}

# --- 4. Checksums -------------------------------------------------------------
$hash = (Get-FileHash $out -Algorithm SHA256).Hash.ToLower()
"$hash  $name" | Set-Content -Encoding ascii (Join-Path $dist "SHA256SUMS")

Write-Host ""
Write-Host "Built:  $out"
Write-Host "SHA256: $hash"
Write-Host "Source: cloudflare/cloudflared@$Version ($commit)"

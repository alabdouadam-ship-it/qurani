# ============================================================================
# Qurani release build helper (Windows / PowerShell)
# ============================================================================
# ALWAYS builds with the Supabase credentials injected via --dart-define-from-file.
# A plain `flutter build appbundle --release` silently ships a build with NO
# Supabase config (no news, no stats, no DB reciters), because the credentials
# are compile-time defines. This script makes that mistake impossible.
#
# Usage (from the project root):
#   ./tool/build_release.ps1                # default: Android App Bundle (AAB)
#   ./tool/build_release.ps1 apk            # Android APK
#   ./tool/build_release.ps1 ipa            # iOS (on macOS only)
#   ./tool/build_release.ps1 web            # Web
#   ./tool/build_release.ps1 install        # build + install release APK on a device
# ============================================================================

$ErrorActionPreference = 'Stop'

# Resolve project root = parent of this script's folder, so it works from anywhere.
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$envFile = Join-Path $root 'supabase.env.json'

# --- Fail fast if the credentials file is missing -------------------------
if (-not (Test-Path $envFile)) {
    Write-Host ''
    Write-Host 'ERROR: supabase.env.json not found at project root.' -ForegroundColor Red
    Write-Host 'This file holds SUPABASE_URL + SUPABASE_PUBLISHABLE_KEY and is gitignored.' -ForegroundColor Red
    Write-Host 'Copy supabase.env.example.json to supabase.env.json and fill in the values,' -ForegroundColor Red
    Write-Host 'then re-run. Building without it ships a broken (Supabase-disabled) app.' -ForegroundColor Red
    exit 1
}

# --- Sanity-check the file actually contains real values ------------------
try {
    $envJson = Get-Content $envFile -Raw | ConvertFrom-Json
} catch {
    Write-Host "ERROR: supabase.env.json is not valid JSON." -ForegroundColor Red
    exit 1
}
if ([string]::IsNullOrWhiteSpace($envJson.SUPABASE_URL) -or
    ($envJson.SUPABASE_URL -like '*<*')) {
    Write-Host "ERROR: SUPABASE_URL in supabase.env.json is empty or a placeholder." -ForegroundColor Red
    exit 1
}
if ([string]::IsNullOrWhiteSpace($envJson.SUPABASE_PUBLISHABLE_KEY) -or
    ($envJson.SUPABASE_PUBLISHABLE_KEY -like '*<*')) {
    Write-Host "ERROR: SUPABASE_PUBLISHABLE_KEY in supabase.env.json is empty or a placeholder." -ForegroundColor Red
    exit 1
}

$target = if ($args.Count -ge 1) { $args[0].ToLower() } else { 'appbundle' }
$define = "--dart-define-from-file=supabase.env.json"

Write-Host "Building '$target' (release) with Supabase config from supabase.env.json..." -ForegroundColor Cyan

switch ($target) {
    'appbundle' { flutter build appbundle --release $define }
    'aab'       { flutter build appbundle --release $define }
    'apk'       { flutter build apk --release $define }
    'ipa'       { flutter build ipa --release $define }
    'web'       { flutter build web --release $define }
    'install'   { flutter install --release $define }
    default {
        Write-Host "Unknown target '$target'. Use: appbundle | apk | ipa | web | install" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Done. (Supabase URL: $($envJson.SUPABASE_URL))" -ForegroundColor Green

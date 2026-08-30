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

# The Flutter CLI writes informational lines to stderr (notably "Wasm dry run
# findings:" on web builds). Under `$ErrorActionPreference = 'Stop'` PowerShell
# turns any native-command stderr into a terminating NativeCommandError, which
# ABORTED this script part-way through the build and left a silently truncated
# output directory (observed: a `build/web` with 21 files and no `assets/` at
# all, which would then have been deployed as-is). So relax the preference
# around the build itself and judge success by the exit code instead.
$previousEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'

switch ($target) {
    'appbundle' { flutter build appbundle --release $define }
    'aab'       { flutter build appbundle --release $define }
    'apk'       { flutter build apk --release $define }
    'ipa'       { flutter build ipa --release $define }
    'web'       { flutter build web --release $define }
    'install'   { flutter install --release $define }
    default {
        $ErrorActionPreference = $previousEap
        Write-Host "Unknown target '$target'. Use: appbundle | apk | ipa | web | install" -ForegroundColor Red
        exit 1
    }
}

$buildExit = $LASTEXITCODE
$ErrorActionPreference = $previousEap

if ($buildExit -ne 0) {
    Write-Host ''
    Write-Host "ERROR: 'flutter build $target' exited with code $buildExit." -ForegroundColor Red
    Write-Host 'The output directory may be incomplete - do NOT deploy or upload it.' -ForegroundColor Red
    exit $buildExit
}

# --- Web only: drop the io-only SQLite payload from the deploy -------------
# The bundled Quran database is read ONLY by quran_database_service, which is
# io-only (dart:io + sqflite). The web app reads Quran text from the sharded
# JSON served via jsDelivr instead, so no web client ever requests these files -
# they just sit in `build/web` inflating Firebase Hosting storage on every
# release. Hosting storage is free to 10 GB and every retained release keeps its
# own copy, so this is the difference between roughly 36 and 150 retained
# releases. They cannot be excluded via pubspec.yaml (one asset list, shared
# with mobile, which genuinely needs them), hence pruning here.
#
# Listed rather than hardcoded to one path because the payload has already moved
# once: it used to be a single `assets/data/quran.db`, and is now the gzipped
# split parts under `assets/data/quran_db/` produced by tool/pack_quran_db.dart.
# The rename silently un-pruned the payload and put 29 MB back into build/web,
# so the check below warns when NOTHING matched - if this list goes stale again,
# the build says so instead of quietly shipping the database to the web.
if ($target -eq 'web') {
    $ioOnlyAssets = @(
        'build/web/assets/assets/data/quran_db', # gzipped split parts (current)
        'build/web/assets/assets/data/quran.db'  # unsplit file (pre-e495e50)
    )
    $prunedMb = 0
    foreach ($rel in $ioOnlyAssets) {
        $path = Join-Path $root $rel
        if (-not (Test-Path $path)) { continue }
        $mb = [math]::Round(
            ((Get-ChildItem $path -Recurse -File |
                Measure-Object Length -Sum).Sum / 1MB), 2)
        Remove-Item $path -Recurse -Force
        $prunedMb += $mb
        Write-Host "Pruned $(Split-Path $rel -Leaf) from build/web ($mb MB, unused on web)." -ForegroundColor Cyan
    }
    if ($prunedMb -eq 0) {
        Write-Host "WARNING: no io-only database asset found to prune. If the asset was renamed, update `$ioOnlyAssets in tool/build_release.ps1 - otherwise the web deploy is carrying it." -ForegroundColor Yellow
    }
    $webTotal = [math]::Round(
        ((Get-ChildItem (Join-Path $root 'build/web') -Recurse -File |
            Measure-Object Length -Sum).Sum / 1MB), 2)
    Write-Host "build/web payload: $webTotal MB" -ForegroundColor Cyan
}

Write-Host "Done. (Supabase URL: $($envJson.SUPABASE_URL))" -ForegroundColor Green

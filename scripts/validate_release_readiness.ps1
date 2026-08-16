param(
  [switch]$RequireLocalSecrets
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function Fail($message) {
  Write-Error $message
  exit 1
}

function Assert-FileDoesNotContain($path, $pattern, $message) {
  if (-not (Test-Path $path)) {
    Fail "Missing required file: $path"
  }
  $match = Select-String -Path $path -Pattern $pattern -SimpleMatch -ErrorAction SilentlyContinue
  if ($match) {
    Fail $message
  }
}

Push-Location $repoRoot
try {
  $status = git status --short --untracked-files=all
  $unexpected = $status | Where-Object {
    $_ -match '^\?\? (package\.json|package-lock\.json|node_modules/)'
  }
  if ($unexpected) {
    Fail "Unexpected Node artifact(s) in repo root: $($unexpected -join ', ')"
  }

  Assert-FileDoesNotContain `
    "ios/Runner/Info.plist" `
    "YOUR_GOOGLE_MAPS_API_KEY_HERE" `
    "iOS Info.plist still contains the Google Maps placeholder."

  $infoPlist = Get-Content "ios/Runner/Info.plist" -Raw
  if ($infoPlist -notmatch '\$\(GOOGLE_MAPS_API_KEY\)') {
    Fail "iOS Info.plist must reference `$`(GOOGLE_MAPS_API_KEY`) for release substitution."
  }

  $releaseConfig = Get-Content "ios/Flutter/Release.xcconfig" -Raw
  if ($releaseConfig -notmatch 'ReleaseSecrets\.xcconfig') {
    Fail "iOS Release.xcconfig must optionally include ReleaseSecrets.xcconfig."
  }

  if ($RequireLocalSecrets) {
    if (-not (Test-Path "ios/Flutter/ReleaseSecrets.xcconfig")) {
      Fail "Missing ios/Flutter/ReleaseSecrets.xcconfig. Copy the example and add the restricted iOS key."
    }
    Assert-FileDoesNotContain `
      "ios/Flutter/ReleaseSecrets.xcconfig" `
      "YOUR_IOS_RESTRICTED_GOOGLE_MAPS_API_KEY" `
      "iOS ReleaseSecrets.xcconfig still contains the placeholder key."
  }

  $requiredDocs = @(
    "README.md",
    "RELEASE_READINESS.md",
    "docs/LOCAL_ENV_RUN.md",
    "supabase/SECURITY_READINESS.md",
    "security-evidence/rls-audit/RELEASE_EVIDENCE_TEMPLATE.md"
  )
  foreach ($doc in $requiredDocs) {
    if (-not (Test-Path $doc)) {
      Fail "Missing release document: $doc"
    }
  }

  Write-Host "Release readiness repository checks passed."
}
finally {
  Pop-Location
}

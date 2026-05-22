$ErrorActionPreference = 'Stop'
$FlutterArgs = $args

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path (Join-Path $scriptDir '..')
Set-Location $projectRoot

$envFile = Join-Path $projectRoot '.env.local.json'
$exampleFile = Join-Path $projectRoot '.env.local.json.example'
$requiredKeys = @(
  'SUPABASE_URL',
  'SUPABASE_ANON_KEY',
  'GOOGLE_MAPS_API_KEY',
  'GOOGLE_PLACES_API_KEY'
)

if (-not (Test-Path -LiteralPath $envFile -PathType Leaf)) {
  Write-Error 'Copy .env.local.json.example to .env.local.json and fill real values.'
  exit 1
}

try {
  $config = Get-Content -LiteralPath $envFile -Raw | ConvertFrom-Json
} catch {
  Write-Error ".env.local.json must be valid JSON. Start from $exampleFile and fill real values."
  exit 1
}

$missingKeys = @()
foreach ($key in $requiredKeys) {
  $property = $config.PSObject.Properties[$key]
  if ($null -eq $property -or
      $null -eq $property.Value -or
      [string]::IsNullOrWhiteSpace([string] $property.Value)) {
    $missingKeys += $key
  }
}

if ($missingKeys.Count -gt 0) {
  Write-Error ('.env.local.json is missing required keys: ' + ($missingKeys -join ', '))
  exit 1
}

flutter run --dart-define-from-file=.env.local.json @FlutterArgs

# Local Env Run

Local debug and release runs should use Dart defines. `.env` is ignored by git
and is not bundled as a Flutter asset, so do not rely on plain `flutter run`
for configured app services.

## Optional Local `.env`

Create a local `.env` file in the project root only if you need a scratch
source for copying values into `.env.local.json`. It is ignored by git.

```text
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
GOOGLE_PLACES_API_KEY=your_google_places_api_key
```

Required keys:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `GOOGLE_MAPS_API_KEY`
- `GOOGLE_PLACES_API_KEY`

Do not commit `.env`.

## Optional Dart Define Config

```powershell
Copy-Item .env.local.json.example .env.local.json
```

Fill `.env.local.json` with real local values. Required keys:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `GOOGLE_MAPS_API_KEY`
- `GOOGLE_PLACES_API_KEY`

Do not commit `.env.local.json`.

## Terminal

```powershell
powershell ./scripts/run_dev.ps1
```

Equivalent Flutter command:

```powershell
flutter run --dart-define-from-file=.env.local.json
```

Extra Flutter arguments can be passed through the script:

```powershell
powershell ./scripts/run_dev.ps1 -d chrome
```

## VS Code

Select `Flutter Debug with Local Env` from Run and Debug. The launch profile passes:

```text
--dart-define-from-file=.env.local.json
```

## Android Studio

Android Studio run configurations are usually local machine state. Configure it manually:

1. Open `Run > Edit Configurations`.
2. Select the Flutter run configuration for this app.
3. Add this to `Additional run args`:

```text
--dart-define-from-file=.env.local.json
```

## Expected Logs

Successful Dart define bootstrap should include:

```text
[ENV_CONFIG] SUPABASE_URL=present source=dart_define
[ENV_CONFIG] SUPABASE_ANON_KEY=present source=dart_define
[ENV_CONFIG] GOOGLE_MAPS_API_KEY=present source=dart_define
[ENV_CONFIG] GOOGLE_PLACES_API_KEY=present source=dart_define
[SUPABASE_INIT] configured=true missingKeys=
```

## Release Cleanup

Before release:

- Keep `.env` out of `pubspec.yaml` assets.
- Use `--dart-define`, `--dart-define-from-file`, or CI secrets instead.
- Verify `.env` is not bundled in build artifacts.
- Configure Android release signing with `android/key.properties` or CI
  environment variables:
  - `ANDROID_KEYSTORE_PATH`
  - `ANDROID_KEYSTORE_PASSWORD`
  - `ANDROID_KEY_ALIAS`
  - `ANDROID_KEY_PASSWORD`
- Keep `android/key.properties` out of git.
- Restrict Google API keys by package name/SHA-1, bundle ID, HTTP referrer, and API surface as appropriate.
- Verify Supabase anon key policies and RLS before shipping.

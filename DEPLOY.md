# Deploy & Update Workflow — prem_kirana_ledger

This repo auto-builds and releases an APK on every push to `main`, and the
app itself checks for updates on launch. No wifi/USB transfer needed.

## How it works

1. You edit code locally.
2. Bump the version in `pubspec.yaml` (e.g. `1.0.1+2` → `1.0.2+3`).
   - Format: `version: <version>+<build>` — the build number is what
     the update-checker compares, so it must increase every release.
3. `git add . && git commit -m "..." && git push`
4. GitHub Actions (`.github/workflows/build-release.yml`) automatically:
   - Builds the release APK
   - Creates a GitHub Release tagged `v<version>-<build>` with the APK attached
   - Generates a changelog from commit messages since the last tag
   - Writes/commits `version.json` to the repo root with the new version,
     build number, APK download URL, and changelog notes
5. Next time the app is opened on a phone, it fetches `version.json`,
   compares build numbers, and — if a newer build exists — shows an
   "Update Available" dialog with the changelog and an Update button
   that opens the APK download link.

## One-time setup (already done for this repo)

- `android/`, `ios/` platform folders generated via
  `flutter create --project-name prem_kirana_ledger --org com.eren .`
- `AndroidManifest.xml` permissions added: CAMERA, INTERNET,
  READ/WRITE_EXTERNAL_STORAGE (maxSdk 28), camera `<uses-feature>` set
  to not required.
- Repo pushed to GitHub as `AnshNagre/prem_kirana_ledger`, set to
  **public** (required so `raw.githubusercontent.com/.../version.json`
  is reachable without auth — private repos 404 on that URL for
  unauthenticated requests, including the app's own HTTP call).
- Actions → General → Workflow permissions set to **Read and write**
  (needed so the workflow can create releases and push `version.json`
  back to the repo).
- `.gitignore` updated so `android/`, `ios/` etc. are tracked, while
  `.gradle/`, `.kotlin/`, `local.properties`, `build/` stay ignored.
- `lib/utils/update_checker.dart` added — fetches `version.json`,
  compares build numbers, shows the update dialog.
- `home_dashboard.dart` converted to a `StatefulWidget` with
  `initState()` calling `UpdateChecker.checkForUpdate(context)`.
- Flutter version pinned in the workflow to match local: `3.44.6`.

## Known gotchas (already solved once, in case they resurface)

- **"Unsupported Gradle project" / missing `build.gradle`**: caused by
  CI's Flutter version not matching the local version that generated
  the `android/` folder. Keep the `flutter-version:` in the workflow
  in sync with your local `flutter --version`.
- **`version.json` 404 on `raw.githubusercontent.com`**: only happens
  if the repo is private. Keep it public, or switch to an
  authenticated fetch (not currently implemented).
- **First release has no update-checker code**: the very first APK
  built before `update_checker.dart` existed will never show a
  popup, since the code isn't in that build. Only builds *after* the
  checker was added can detect and prompt for further updates.

## Two-device note

Each device checks independently on its own app open — there's no
push notification or silent auto-install. Updating requires opening
the app and tapping through the dialog on **each** device separately.

## Future apps

This exact pipeline (workflow YAML + `version.json` + update-checker
widget) can be copied to other personal apps (e.g. Kirana Khata) —
just swap the GitHub repo path in `update_checker.dart`'s
`versionJsonUrl`.

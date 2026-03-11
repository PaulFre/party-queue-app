# Party Queue MVP

First functional MVP for a cross-platform Android/iOS party app with host/guest roles, live voting, and dynamic queue rules.

## Run

```bash
flutter pub get
flutter run -d chrome
```

For a quick non-resident browser smoke run:

```bash
flutter run -d chrome --no-resident
```

## Quality Gate

```bash
flutter analyze
flutter test
flutter build web
```

Coverage locally:

```bash
flutter test --coverage
```

CI enforces a minimum line coverage of `45%` from `coverage/lcov.info`.

Firestore Security Rules (Emulator):

```bash
npm install
npm run test:firestore:emulator
```

Windows shortcut script:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\dev_smoke.ps1 -SkipChromeRun
```

## CI and Branch Protection

- GitHub Actions workflow: `.github/workflows/ci.yml`
  - Job `Quality Gate` (`analyze`, `test`, `build web`)
  - Job `Coverage` (`flutter test --coverage`, minimum line coverage: `45%`)
  - Job `Firestore Security Rules` (`firebase emulators:exec` + rule tests)
  - Coverage artifact: `coverage-lcov`
  - Required Codecov upload (non-fork PRs and pushes) via repository secret `CODECOV_TOKEN`

To apply branch protection for `main` via API:

```powershell
$env:GITHUB_TOKEN="<token-with-repo-admin-rights>"
powershell -ExecutionPolicy Bypass -File .\tool\setup_branch_protection.ps1 -Owner <org-or-user> -Repo <repo-name>
```

Config lives in `.github/branch-protection.json`.

## GitHub Pages Deployment

- Workflow: `.github/workflows/deploy-pages.yml`
- Trigger: push on `main` or manual run (`workflow_dispatch`)
- Output: published Flutter Web build on GitHub Pages

One-time repository setup:
1. GitHub repository `Settings` -> `Pages`
2. Under `Build and deployment`, set `Source` to `GitHub Actions`
3. Push to `main` (or run the workflow manually in `Actions`)

The workflow automatically sets Flutter `--base-href`:
- `"/"` for `<owner>.github.io` repositories
- `"/<repo-name>/"` for project pages

## Product Planning Artifacts

- `docs/01_MVP_Scope_Checklist.md`
- `docs/02_Production_Gap_Roadmap.md`

## Included MVP Features

- Host creates a room and "connects Spotify Premium" (mocked integration flow).
- Guests join via room code, invite link, or QR scan.
- Guests can add songs and vote (one like/dislike per user per song).
- Queue sorting:
  - Default: `likes - dislikes`
  - Optional: age bonus
- Host controls:
  - Pin, remove, skip
  - Pause voting
  - Host-only adds
  - Lock room
  - Democratic / Suggestions-only mode
- Suggestions flow with host approve/reject.
- Rules:
  - No duplicate songs in active queue
  - Cooldown after played song (default 30 min, configurable)
  - Anti-spam add limit (default 3 songs per 10 min, configurable)
  - Fairness mode (on by default)
  - Freeze window before next start
  - Explicit content block + genre exclusions
- Reconnect flow:
  - Simulate token expired / device unavailable
  - Host reconnect action
- UI widgets:
  - Now playing / Next / Queue status bar
  - Top-voted widget
  - Lockscreen live preview card
  - Guest avatars + names in queue
- End party:
  - Generate post-party "top played songs" playlist summary (mocked export dialog).
- Realtime sync (Step 1) with Firebase:
  - Optional Firebase mode in Host/Join setup
  - Host is authoritative for live playback state
  - Guests send realtime commands (`add song`, `vote`)
  - All clients subscribe to shared room snapshots in Firestore
  - Automatic fallback to local mode if Firebase is not configured

## Firebase Setup (for real multi-device rooms)

1. Create a Firebase project.
2. Enable:
   - Authentication -> Anonymous
   - Cloud Firestore
3. Run FlutterFire configuration for this app:

```bash
flutterfire configure
```

4. Add generated platform config files (`google-services.json` / `GoogleService-Info.plist`) to the project.
5. Start app again with `flutter run`.

If Firebase is missing or init fails, the app still starts and runs in local demo mode.

## Realtime Architecture

- Room state is stored in Firestore document: `party_rooms/{roomCode}`.
- Guest actions are queued in: `party_rooms/{roomCode}/commands`.
- Host client listens to pending commands, applies business rules, and republishes authoritative room state.
- All connected clients subscribe to room snapshots for live sync.
- Command protocol is hardened:
  - strict payload validation per command type
  - stale-command rejection (replay protection window)
  - structured error codes (`ActionResult.code`) and telemetry events (`engine.recentTelemetry`)

## Technical Note

Spotify search and playback are still mocked in this version.  
Next step is replacing the mock catalog/playback adapter with real Spotify OAuth + Web API calls while keeping the same room engine and realtime sync flow.

Smoke check on 2026-03-11.

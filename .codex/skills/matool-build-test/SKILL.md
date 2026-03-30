---
name: matool-build-test
description: MaToolリポジトリでBackendとiOSAppのbuild/testを安全に実行する。Backend/Package.swiftとXcode scheme構成を前提にコマンドを固定し、BackendBootstrap（Backend/Bootstrap）を絶対に実行しない運用が必要なときに使う。
---

# MaTool Build/Test Workflow

- Use this skill when the user asks to run or verify `Backend` or `iOSApp` build/test in `/Users/matsushitakazuya/private/MaTool`.
- Run commands from the repository root: `/Users/matsushitakazuya/private/MaTool`.
- Never execute bootstrap routines. Treat all of these as forbidden:
  - `BackendBootstrap` scheme
  - `Backend/Bootstrap` test target
  - Unfiltered `swift test` in `Backend/` that may include bootstrap

## Safety-First Command Set

Use the bundled script to avoid accidental bootstrap execution:

```bash
./.codex/skills/matool-build-test/scripts/safe_build_test.sh <action>
```

Supported actions:
- `list`: Show detected package/scheme structure and planned commands.
- `backend-build`: Run backend build only.
- `backend-test`: Run backend tests with `--filter BackendTests` only.
- `backend-run`: Run backend executable on My Mac.
- `ios-build`: Build iOS app with scheme `iOSApp`.
- `ios-test`: Test iOS app with scheme `iOSAppTests`.
- `ios-run`: Build and launch iOS app on an auto-selected available simulator.
- `all`: Run `backend-build -> backend-test -> ios-build -> ios-test`.

## Direct Commands (When Script Cannot Be Used)

```bash
# Backend
xcodebuild -workspace MaTool.xcworkspace -scheme Backend -destination 'platform=macOS' build
xcodebuild -workspace MaTool.xcworkspace -scheme BackendTests -destination 'platform=macOS' test
# run: build Backend scheme, then execute built Backend binary on My Mac

# iOSApp
xcodebuild -workspace MaTool.xcworkspace -scheme iOSApp -destination 'generic/platform=iOS Simulator' build
xcodebuild -workspace MaTool.xcworkspace -scheme iOSAppTests -destination 'id=<auto-selected-available-simulator-udid>' test
xcodebuild -workspace MaTool.xcworkspace -scheme iOSApp -destination 'id=<auto-selected-available-simulator-udid>' build
xcrun simctl boot '<auto-selected-available-simulator-udid>'
xcrun simctl install booted <path-to-MaTool.app>
xcrun simctl launch booted <bundle-id>
```

## Default Execution Context

- iOS destination is selected dynamically from available simulator devices.
- Selection policy prioritizes standard `iPhone <number>` models, then newest iOS runtime.
- Override iOS destination/device when task context requires specific OS/device reproduction.
- `ios-run` is fronted by Simulator.app by default (`OPEN_SIMULATOR_APP=1`).
- After iOSApp code changes, run `ios-run` unless the user explicitly says not to.
- Backend build/test/run uses Workspace schemes (`Backend`, `BackendTests`) on My Mac by default.

## Scheme/Package Expectations

This skill assumes the repository currently contains:
- `Backend/Package.swift` with targets: `Backend`, `BackendTests`, `BackendBootstrap`
- `Backend/.swiftpm/xcode/xcshareddata/xcschemes/Backend.xcscheme`
- `Backend/.swiftpm/xcode/xcshareddata/xcschemes/BackendTests.xcscheme`
- `Backend/.swiftpm/xcode/xcshareddata/xcschemes/BackendBootstrap.xcscheme` (must exist but must not be executed)
- `iOSApp/MaTool.xcodeproj/xcshareddata/xcschemes/iOSApp.xcscheme`
- `iOSApp/MaTool.xcodeproj/xcshareddata/xcschemes/iOSAppTests.xcscheme`

If expected files are missing, re-check current project structure before running build/test.

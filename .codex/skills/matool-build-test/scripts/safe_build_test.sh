#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

ACTION="${1:-list}"
IOS_BUILD_DESTINATION="${IOS_BUILD_DESTINATION:-generic/platform=iOS Simulator}"
IOS_TEST_DESTINATION="${IOS_TEST_DESTINATION:-}"
IOS_RUN_DESTINATION="${IOS_RUN_DESTINATION:-}"
IOS_RUN_DEVICE_NAME="${IOS_RUN_DEVICE_NAME:-}"
IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-}"
OPEN_SIMULATOR_APP="${OPEN_SIMULATOR_APP:-1}"

BACKEND_PACKAGE="${REPO_ROOT}/Backend/Package.swift"
SHARED_PACKAGE="${REPO_ROOT}/Shared/Package.swift"
BACKEND_SCHEME_DIR="${REPO_ROOT}/Backend/.swiftpm/xcode/xcshareddata/xcschemes"
IOS_SCHEME_DIR="${REPO_ROOT}/iOSApp/MaTool.xcodeproj/xcshareddata/xcschemes"

fail() {
  echo "[ERROR] $*" >&2
  exit 1
}

ensure_file() {
  local file="$1"
  [[ -f "${file}" ]] || fail "Missing file: ${file}"
}

ensure_contains() {
  local file="$1"
  local pattern="$2"
  rg -q --fixed-strings "${pattern}" "${file}" || fail "Expected pattern '${pattern}' in ${file}"
}

verify_structure() {
  ensure_file "${BACKEND_PACKAGE}"
  ensure_file "${SHARED_PACKAGE}"
  ensure_file "${BACKEND_SCHEME_DIR}/Backend.xcscheme"
  ensure_file "${BACKEND_SCHEME_DIR}/BackendTests.xcscheme"
  ensure_file "${BACKEND_SCHEME_DIR}/BackendBootstrap.xcscheme"
  ensure_file "${IOS_SCHEME_DIR}/iOSApp.xcscheme"
  ensure_file "${IOS_SCHEME_DIR}/iOSAppTests.xcscheme"

  ensure_contains "${BACKEND_PACKAGE}" "name: \"Backend\""
  ensure_contains "${BACKEND_PACKAGE}" "name: \"BackendTests\""
  ensure_contains "${BACKEND_PACKAGE}" "name: \"BackendBootstrap\""

  ensure_contains "${BACKEND_SCHEME_DIR}/BackendBootstrap.xcscheme" "BlueprintName = \"BackendBootstrap\""
  ensure_contains "${IOS_SCHEME_DIR}/iOSApp.xcscheme" "BlueprintName = \"iOSApp\""
  ensure_contains "${IOS_SCHEME_DIR}/iOSAppTests.xcscheme" "BlueprintName = \"iOSAppTests\""
}

cmd_backend_build() {
  (
    cd "${REPO_ROOT}/Backend"
    swift build --product Backend
  )
}

cmd_backend_test() {
  (
    cd "${REPO_ROOT}/Backend"
    # Always filter to BackendTests so BackendBootstrap never runs.
    swift test --filter BackendTests
  )
}

cmd_ios_build() {
  (
    cd "${REPO_ROOT}"
    xcodebuild \
      -workspace MaTool.xcworkspace \
      -scheme iOSApp \
      -destination "${IOS_BUILD_DESTINATION}" \
      build
  )
}

cmd_ios_test() {
  local destination
  destination="$(resolve_destination "${IOS_TEST_DESTINATION}")"
  (
    cd "${REPO_ROOT}"
    xcodebuild \
      -workspace MaTool.xcworkspace \
      -scheme iOSAppTests \
      -destination "${destination}" \
      test
  )
}

cmd_backend_run() {
  (
    cd "${REPO_ROOT}/Backend"
    swift run Backend
  )
}

cmd_ios_run() {
  local app_path
  local destination
  local simulator_udid
  local simulator_name
  local bundle_id
  local tmp_device_info
  local tmp_file
  tmp_file="$(mktemp)"
  tmp_device_info="$(mktemp)"

  destination="$(resolve_destination "${IOS_RUN_DESTINATION}")"
  simulator_udid="$(echo "${destination}" | sed -n 's/^id=\(.*\)$/\1/p')"

  if [[ -z "${simulator_udid}" ]]; then
    simulator_udid="$(resolve_preferred_simulator_udid)"
    destination="id=${simulator_udid}"
  fi

  xcrun simctl list devices available -j | python3 -c '
import json, sys
udid = sys.argv[1]
data = json.load(sys.stdin)
for _, devices in data.get("devices", {}).items():
    for d in devices:
        if d.get("udid") == udid:
            print(d.get("name", "unknown"))
            raise SystemExit(0)
print("unknown")
' "${simulator_udid}" > "${tmp_device_info}"
  simulator_name="$(cat "${tmp_device_info}")"

  (
    cd "${REPO_ROOT}"
    xcodebuild \
      -workspace MaTool.xcworkspace \
      -scheme iOSApp \
      -destination "${destination}" \
      build
  )

  (
    cd "${REPO_ROOT}"
    xcodebuild \
      -workspace MaTool.xcworkspace \
      -scheme iOSApp \
      -destination "${destination}" \
      -showBuildSettings \
      | awk -F' = ' '
          $1 ~ /TARGET_BUILD_DIR$/ {build=$2}
          $1 ~ /WRAPPER_NAME$/ {wrapper=$2}
          END {
            if (build == "" || wrapper == "") exit 1
            print build "/" wrapper
          }'
  ) > "${tmp_file}"

  app_path="$(cat "${tmp_file}")"
  [[ -d "${app_path}" ]] || fail "Built app not found: ${app_path}"
  bundle_id="${IOS_BUNDLE_ID}"
  if [[ -z "${bundle_id}" ]]; then
    bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${app_path}/Info.plist" 2>/dev/null || true)"
  fi
  [[ -n "${bundle_id}" ]] || fail "Could not determine bundle identifier. Set IOS_BUNDLE_ID."

  xcrun simctl boot "${simulator_udid}" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "${simulator_udid}" -b
  if [[ "${OPEN_SIMULATOR_APP}" == "1" ]]; then
    open -a Simulator --args -CurrentDeviceUDID "${simulator_udid}" >/dev/null 2>&1 || true
  fi
  xcrun simctl install booted "${app_path}"
  xcrun simctl launch booted "${bundle_id}"
  echo "[INFO] iOS run simulator: ${simulator_name} (${simulator_udid})"
  echo "[INFO] iOS bundle id: ${bundle_id}"
  rm -f "${tmp_file}" "${tmp_device_info}"
}

resolve_preferred_simulator_udid() {
  xcrun simctl list devices available -j | python3 -c '
import json, re, sys

data = json.load(sys.stdin)
candidates = []

for runtime_id, devices in data.get("devices", {}).items():
    version_match = re.search(r"iOS-([0-9]+)-([0-9]+)", runtime_id)
    if not version_match:
        continue
    major = int(version_match.group(1))
    minor = int(version_match.group(2))
    runtime_score = major * 100 + minor
    for d in devices:
        if not d.get("isAvailable"):
            continue
        name = d.get("name", "")
        udid = d.get("udid", "")
        if not name.startswith("iPhone ") or not udid:
            continue

        standard = re.fullmatch(r"iPhone ([0-9]+)", name)
        if standard:
            priority = 0
            generation = int(standard.group(1))
        elif ("Pro" in name) or ("Plus" in name) or ("mini" in name) or ("SE" in name):
            priority = 2
            generation = 0
        else:
            priority = 1
            generation = 0

        # Lower priority wins. Then newer runtime and newer generation.
        candidates.append((priority, -runtime_score, -generation, name, udid))

if not candidates:
    print("")
    raise SystemExit(1)

candidates.sort()
print(candidates[0][4])
'
}

resolve_destination() {
  local override="${1:-}"
  local udid
  if [[ -n "${override}" ]]; then
    echo "${override}"
    return
  fi

  udid="$(resolve_preferred_simulator_udid)"
  [[ -n "${udid}" ]] || fail "Could not find an available iOS simulator."
  echo "id=${udid}"
}

print_plan() {
  local auto_udid
  local auto_name
  local tmp_device_info
  tmp_device_info="$(mktemp)"

  auto_udid="$(resolve_preferred_simulator_udid || true)"
  if [[ -n "${auto_udid}" ]]; then
    xcrun simctl list devices available -j | python3 -c '
import json, sys
udid = sys.argv[1]
data = json.load(sys.stdin)
for _, devices in data.get("devices", {}).items():
    for d in devices:
        if d.get("udid") == udid:
            print(d.get("name", "unknown"))
            raise SystemExit(0)
print("unknown")
' "${auto_udid}" > "${tmp_device_info}"
    auto_name="$(cat "${tmp_device_info}")"
  else
    auto_name="(not found)"
  fi

  cat <<PLAN
[INFO] Repo root: ${REPO_ROOT}
[INFO] Structure check passed.
[INFO] Auto-selected iOS simulator: ${auto_name} ${auto_udid:+(${auto_udid})}

Actions:
  list          - Print this plan only
  backend-build - cd Backend && swift build --product Backend
  backend-test  - cd Backend && swift test --filter BackendTests
  backend-run   - cd Backend && swift run Backend
  ios-build     - xcodebuild -workspace MaTool.xcworkspace -scheme iOSApp -destination '${IOS_BUILD_DESTINATION}' build
  ios-test      - xcodebuild -workspace MaTool.xcworkspace -scheme iOSAppTests -destination '<auto id=... or IOS_TEST_DESTINATION>' test
  ios-run       - Build iOSApp and launch on '<auto id=... or IOS_RUN_DESTINATION>'
  all           - backend-build -> backend-test -> ios-build -> ios-test

Forbidden:
  - BackendBootstrap scheme/test target execution
  - Unfiltered 'swift test' in Backend/
PLAN
  rm -f "${tmp_device_info}"
}

main() {
  verify_structure

  case "${ACTION}" in
    list)
      print_plan
      ;;
    backend-build)
      cmd_backend_build
      ;;
    backend-test)
      cmd_backend_test
      ;;
    backend-run)
      cmd_backend_run
      ;;
    ios-build)
      cmd_ios_build
      ;;
    ios-test)
      cmd_ios_test
      ;;
    ios-run)
      cmd_ios_run
      ;;
    all)
      cmd_backend_build
      cmd_backend_test
      cmd_ios_build
      cmd_ios_test
      ;;
    *)
      fail "Unknown action: ${ACTION}. Use one of: list, backend-build, backend-test, backend-run, ios-build, ios-test, ios-run, all"
      ;;
  esac
}

main "$@"

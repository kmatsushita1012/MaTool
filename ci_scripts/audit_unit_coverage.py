#!/usr/bin/env python3
"""List every in-scope unit-test source and its tool-reported line coverage.

Missing files and 0-executable-line files remain visible in the output.
User-authorized infrastructure exclusions remain visible with their reasons.
No coverage percentage is estimated or altered.
"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


def canonical_path(raw: str) -> str | None:
    value = raw.replace("\\", "/")
    for prefix in ("Backend/Sources/", "iOSApp/Sources/"):
        at = value.find(prefix)
        if at >= 0:
            return value[at:]
    return None


def backend_lines(raw: dict) -> dict[str, tuple[int, int]]:
    found: dict[str, tuple[int, int]] = {}
    for coverage in raw.get("data", []):
        for file in coverage.get("files", []):
            path = canonical_path(file.get("filename", ""))
            lines = file.get("summary", {}).get("lines", {})
            if path and "count" in lines and "covered" in lines:
                found[path] = (int(lines["count"]), int(lines["covered"]))
    return found


def ios_lines(raw: dict) -> dict[str, tuple[int, int]]:
    found: dict[str, tuple[int, int]] = {}
    for target in raw.get("targets", []):
        for file in target.get("files", []):
            path = canonical_path(file.get("path", ""))
            if path and "executableLines" in file and "coveredLines" in file:
                count = int(file["executableLines"])
                covered = int(file["coveredLines"])
                # Avoid replacing application files with target copies of tests.
                if path not in found or count > found[path][0]:
                    found[path] = (count, covered)
    return found


def discovered_swift_targets() -> set[str]:
    """Fail if a checked-out business-logic source is omitted from the target manifest."""
    sources: set[str] = set()
    for root in ("Backend/Sources", "iOSApp/Sources/Application",
                 "iOSApp/Sources/Data", "iOSApp/Sources/Presentation"):
        for source in Path(root).rglob("*.swift"):
            path = source.as_posix()
            if path.startswith(("Backend/Sources/", "iOSApp/Sources/Application/", "iOSApp/Sources/Data/")):
                sources.add(path)
            elif path.startswith("iOSApp/Sources/Presentation/") and (
                path.endswith("Feature.swift")
                or path.endswith("/Onboarding.swift")
                or path.endswith("/ReplayController.swift")
            ):
                sources.add(path)
    return sources

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--full-line-manifest", type=Path, help="Paths requiring measured 100%% line coverage")
    parser.add_argument("--excluded-manifest", type=Path, help="Explicit exclusions (path | reason), kept visible")
    parser.add_argument("--scope", required=True, choices=("backend", "ios"))
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--show-all", action="store_true", help="Print measured coverage for all targets")
    args = parser.parse_args()

    coverage = json.loads(args.input.read_text(encoding="utf-8"))
    lines = backend_lines(coverage) if args.scope == "backend" else ios_lines(coverage)
    paths = [
        line.strip()
        for line in args.manifest.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    missing_from_manifest = discovered_swift_targets().difference(paths)
    if missing_from_manifest:
        raise ValueError(f"HEAD Swift targets absent from coverage manifest: {sorted(missing_from_manifest)}")
    full_targets = set()
    if args.full_line_manifest:
        full_targets = {
            line.strip()
            for line in args.full_line_manifest.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        }
        unknown_targets = full_targets.difference(paths)
        if unknown_targets:
            raise ValueError(f"Full-line targets absent from coverage manifest: {sorted(unknown_targets)}")
    exclusions: dict[str, str] = {}
    if args.excluded_manifest:
        for raw_line in args.excluded_manifest.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if "|" not in line:
                raise ValueError(f"Exclusion requires a path and reason: {line}")
            path, reason = (part.strip() for part in line.split("|", 1))
            if not path or not reason or path in exclusions:
                raise ValueError(f"Invalid or duplicate exclusion: {line}")
            exclusions[path] = reason
        unknown_exclusions = set(exclusions).difference(paths)
        if unknown_exclusions:
            raise ValueError(f"Excluded paths absent from coverage manifest: {sorted(unknown_exclusions)}")

    paths = [
        path
        for path in paths
        if path.startswith("Backend/") == (args.scope == "backend")
    ]

    args.output.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    for path in sorted(paths):
        result = lines.get(path)
        if path in exclusions:
            if result is None:
                rows.append((path, "", "", "", "EXCLUDED"))
            else:
                executable, covered = result
                if covered > executable or covered < 0:
                    raise ValueError(f"Invalid line counts in {path}: {covered}/{executable}")
                percent = f"{100.0 * covered / executable:.4f}" if executable else ""
                rows.append((path, str(executable), str(covered), percent, "EXCLUDED"))
            continue
        if result is None:
            rows.append((path, "", "", "", "MISSING"))
            continue
        executable, covered = result
        if executable == 0:
            rows.append((path, "0", str(covered), "", "NO_EXECUTABLE_LINES"))
            continue
        if covered > executable or covered < 0:
            raise ValueError(f"Invalid line counts in {path}: {covered}/{executable}")
        percent = 100.0 * covered / executable
        rows.append((
            path, str(executable), str(covered), f"{percent:.4f}",
            "PASS" if (covered == executable if path in full_targets else covered * 10 >= executable * 9) else "FAIL"
        ))

    with args.output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(("path", "executable_lines", "covered_lines", "line_coverage_percent", "status"))
        writer.writerows(rows)

    counts = {
        status: sum(row[-1] == status for row in rows)
        for status in ("PASS", "FAIL", "MISSING", "NO_EXECUTABLE_LINES", "EXCLUDED")
    }
    print(f"Coverage audit ({args.scope}): {len(paths)} source files")
    for key, value in counts.items():
        print(f"  {key}: {value}")
    for path, executable, covered, percent, status in rows:
        if args.show_all or status != "PASS":
            print(f"  [{status}] {path}: {covered}/{executable} ({percent or 'N/A'}%)"
                  + (f" — {exclusions[path]}" if status == "EXCLUDED" else ""))

    return 1 if args.strict and counts["PASS"] + counts["EXCLUDED"] != len(paths) else 0


if __name__ == "__main__":
    raise SystemExit(main())

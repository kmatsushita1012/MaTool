#!/usr/bin/env python3
"""Audit instrumented source-line coverage while preserving raw xccov measurements.

User-authorized infrastructure source regions are explicit and visible; compiler-
generated counters without Swift source positions remain in raw summary columns.
No measured count is guessed or modified. Missing/unknown files fail the audit.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
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


# The summary can contain Swift macro-generated counters without source positions.
# xccov --archive --file is the actual per-Swift-source-line measurement.
SOURCE_COUNTER = re.compile(r"^\s*(\d+):\s*(\d+)(?=\s|$)")


def ios_archive_paths(raw: dict) -> dict[str, str]:
    found: dict[str, str] = {}
    for target in raw.get("targets", []):
        for source in target.get("files", []):
            path = canonical_path(source.get("path", ""))
            if path:
                found[path] = source["path"]
    return found


def infrastructure_regions(manifest: Path | None) -> dict[str, list[tuple[int, int, str]]]:
    found: dict[str, list[tuple[int, int, str]]] = {}
    if manifest is None:
        return found
    for raw_line in manifest.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        parts = [part.strip() for part in line.split("|")]
        if len(parts) != 4:
            raise ValueError(f"Expected path | start-end | start marker | reason: {line}")
        path, span, marker, reason = parts
        if not path or not marker or not reason or "-" not in span:
            raise ValueError(f"Invalid infrastructure source-region exclusion: {line}")
        start, end = (int(part) for part in span.split("-", 1))
        if start < 1 or end < start:
            raise ValueError(f"Invalid infrastructure source-region span: {line}")
        source = Path(path).read_text(encoding="utf-8").splitlines()
        if end > len(source) or not source[start - 1].strip().startswith(marker):
            raise ValueError(f"Stale infrastructure exclusion, inspect latest source: {line}")
        found.setdefault(path, []).append((start, end, reason))
    return found


def actual_ios_source_lines(
    archive_path: str,
    xcresult: Path,
    regions: list[tuple[int, int, str]],
) -> tuple[int, int, int, int]:
    """Count xccov-instrumented source lines; separately report explicit excluded regions."""
    result = subprocess.run(
        ["xcrun", "xccov", "view", "--archive", "--file", archive_path, str(xcresult)],
        capture_output=True, text=True, check=False,
    )
    if result.returncode:
        raise ValueError(f"xccov --archive failed for {archive_path}: {result.stderr[:240]}")
    hits: dict[int, int] = {}
    for line in result.stdout.splitlines():
        match = SOURCE_COUNTER.match(line)
        if match:
            number, hit_count = (int(part) for part in match.groups())
            hits[number] = max(hits.get(number, 0), hit_count)
    if not hits:
        raise ValueError(f"No instrumented Swift source lines in xccov archive: {archive_path}")
    excluded = {
        number
        for start, end, _ in regions
        for number in range(start, end + 1)
    }
    audited = [hit_count for line, hit_count in hits.items() if line not in excluded]
    skipped = [hit_count for line, hit_count in hits.items() if line in excluded]
    if not audited:
        raise ValueError(f"All instrumented source lines excluded: {archive_path}")
    return len(audited), sum(count > 0 for count in audited), len(skipped), sum(count > 0 for count in skipped)


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
    parser.add_argument("--xcresult", type=Path, help="Actual xccov archive, required for Swift source-line auditing")
    parser.add_argument("--infrastructure-regions", type=Path, help="Explicitly authorized infrastructure-only source spans")
    args = parser.parse_args()

    if not args.input.exists() or args.input.stat().st_size == 0:
        print("Coverage audit: UNVERIFIED — no xccov JSON; compilation or test execution failed")
        return 1
    try:
        coverage = json.loads(args.input.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        print("Coverage audit: UNVERIFIED — invalid xccov JSON; compilation or test execution failed")
        return 1
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
    regions = infrastructure_regions(args.infrastructure_regions)
    if set(regions).difference(paths):
        raise ValueError(f"Infrastructure regions not in current scope: {sorted(set(regions).difference(paths))}")
    archive_paths = ios_archive_paths(coverage) if args.scope == "ios" else {}
    if args.scope == "ios" and (not args.xcresult or not args.xcresult.exists()):
        raise ValueError("iOS source-line audit requires a real existing --xcresult archive")

    rows = []
    for path in sorted(paths):
        result = lines.get(path)
        if result is None:
            status = "EXCLUDED" if path in exclusions else "MISSING"
            rows.append((path, "", "", "", status, "", "", "", "0"))
            continue

        raw_executable, raw_covered = result
        if raw_covered > raw_executable or raw_covered < 0:
            raise ValueError(f"Invalid raw line counts in {path}: {raw_covered}/{raw_executable}")
        raw_percent = f"{100.0 * raw_covered / raw_executable:.4f}" if raw_executable else ""
        if path in exclusions:
            rows.append((
                path, str(raw_executable), str(raw_covered), raw_percent,
                "EXCLUDED", str(raw_executable), str(raw_covered), raw_percent, "0",
            ))
            continue
        if raw_executable == 0:
            rows.append((path, "0", str(raw_covered), "", "NO_EXECUTABLE_LINES", "0", str(raw_covered), "", "0"))
            continue

        audited_executable, audited_covered = raw_executable, raw_covered
        skipped_lines = 0
        if args.scope == "ios":
            archive_path = archive_paths.get(path)
            if not archive_path:
                rows.append((
                    path, str(raw_executable), str(raw_covered), raw_percent,
                    "UNVERIFIED", str(raw_executable), str(raw_covered), raw_percent, "0",
                ))
                continue
            try:
                audited_executable, audited_covered, skipped_lines, _ = actual_ios_source_lines(
                    archive_path, args.xcresult, regions.get(path, []),
                )
            except ValueError as error:
                print(f"  [UNVERIFIED] {path}: {error}")
                rows.append((
                    path, str(raw_executable), str(raw_covered), raw_percent,
                    "UNVERIFIED", str(raw_executable), str(raw_covered), raw_percent, "0",
                ))
                continue
        percent = 100.0 * audited_covered / audited_executable
        passed = (
            audited_covered == audited_executable
            if path in full_targets
            else audited_covered * 10 >= audited_executable * 9
        )
        rows.append((
            path, str(audited_executable), str(audited_covered), f"{percent:.4f}",
            "PASS" if passed else "FAIL",
            str(raw_executable), str(raw_covered), raw_percent, str(skipped_lines),
        ))

    with args.output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow((
            "path", "executable_lines", "covered_lines", "line_coverage_percent", "status",
            "raw_xccov_executable_lines", "raw_xccov_covered_lines",
            "raw_xccov_line_coverage_percent", "excluded_infrastructure_source_lines",
        ))
        writer.writerows(rows)

    counts = {
        status: sum(row[4] == status for row in rows)
        for status in ("PASS", "FAIL", "MISSING", "UNVERIFIED", "NO_EXECUTABLE_LINES", "EXCLUDED")
    }
    print(f"Coverage audit ({args.scope}): {len(paths)} source files")
    for key, value in counts.items():
        print(f"  {key}: {value}")
    for row in rows:
        path, executable, covered, percent, status = row[:5]
        if args.show_all or status != "PASS":
            raw = f"; raw xccov {row[6]}/{row[5]} ({row[7] or 'N/A'}%)" if args.scope == "ios" else ""
            skipped = f"; infrastructure source lines excluded {row[8]}" if int(row[8]) else ""
            print(f"  [{status}] {path}: {covered}/{executable} ({percent or 'N/A'}%)"
                  + raw + skipped
                  + (f" — {exclusions[path]}" if status == "EXCLUDED" else ""))

    return 1 if args.strict and counts["PASS"] + counts["EXCLUDED"] != len(paths) else 0


if __name__ == "__main__":
    raise SystemExit(main())

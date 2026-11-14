#!/usr/bin/env python3
"""List every in-scope unit-test source and its tool-reported line coverage.

Missing files and 0-executable-line files remain visible in the output.
No target is silently excluded, and no coverage percentage is estimated.
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--full-line-manifest", type=Path, help="Paths requiring measured 100% line coverage")
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
    paths = [
        path
        for path in paths
        if path.startswith("Backend/") == (args.scope == "backend")
    ]

    args.output.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    for path in sorted(paths):
        result = lines.get(path)
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
        for status in ("PASS", "FAIL", "MISSING", "NO_EXECUTABLE_LINES")
    }
    print(f"Coverage audit ({args.scope}): {len(paths)} source files")
    for key, value in counts.items():
        print(f"  {key}: {value}")
    for path, executable, covered, percent, status in rows:
        if args.show_all or status != "PASS":
            print(f"  [{status}] {path}: {covered}/{executable} ({percent or 'N/A'}%)")

    return 1 if args.strict and counts["PASS"] != len(paths) else 0


if __name__ == "__main__":
    raise SystemExit(main())

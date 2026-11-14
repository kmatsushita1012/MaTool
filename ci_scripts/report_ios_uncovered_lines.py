#!/usr/bin/env python3
"""Show actual unexecuted Swift source lines for failed per-file iOS coverage gates.

Reads xccov's raw archive; does not estimate, transform, or change coverage counts.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
from pathlib import Path

from audit_unit_coverage import canonical_path

ZERO_COUNT_LINE = re.compile(r"^\s*(\d+):\s*0(?:\s|$)")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--xcresult", required=True, type=Path)
    parser.add_argument("--coverage", required=True, type=Path)
    parser.add_argument("--csv", required=True, type=Path)
    args = parser.parse_args()

    if not all(p.exists() for p in (args.xcresult, args.coverage, args.csv)):
        print("Uncovered-lines report: coverage bundle or report is not available")
        return 0

    with args.csv.open(encoding="utf-8", newline="") as stream:
        failures = {row["path"] for row in csv.DictReader(stream) if row["status"] == "FAIL"}
    if not failures:
        print("Uncovered-lines report: no failed iOS files")
        return 0

    raw = json.loads(args.coverage.read_text(encoding="utf-8"))
    coverage_paths = {
        canonical_path(source.get("path", "")): source.get("path", "")
        for target in raw.get("targets", [])
        for source in target.get("files", [])
    }

    print(f"Uncovered-lines report: {len(failures)} failed source files (xccov raw counts)")
    for source in sorted(failures):
        archived_path = coverage_paths.get(source)
        if not archived_path:
            print(f"  [UNAVAILABLE] {source}: no archive path")
            continue

        result = subprocess.run(
            ["xcrun", "xccov", "view", "--archive", "--file",
             archived_path, str(args.xcresult)],
            capture_output=True, text=True, check=False,
        )
        if result.returncode:
            print(f"  [UNAVAILABLE] {source}: xccov exit {result.returncode}; "
                  f"{result.stderr.strip()[:160]}")
            continue

        missed_lines = [
            int(match.group(1))
            for line in result.stdout.splitlines()
            if (match := ZERO_COUNT_LINE.match(line))
        ]
        if not missed_lines:
            print(f"  [NO SOURCE LINE] {source}: check compiler-generated coverage")
            continue

        lines = Path(source).read_text(encoding="utf-8").splitlines()
        print(f"  [UNCOVERED] {source}: {len(missed_lines)} source line positions")
        for number in missed_lines:
            source_text = lines[number - 1].strip() if 0 < number <= len(lines) else ""
            print(f"    L{number}: {source_text[:150]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

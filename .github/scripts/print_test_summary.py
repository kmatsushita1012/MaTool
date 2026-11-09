#!/usr/bin/env python3

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def text(value):
    return " ".join(str(value or "").split())


def read_xcresult(path):
    summary = json.loads(Path(path).read_text())
    configuration = (summary.get("devicesAndConfigurations") or [{}])[0]
    device = configuration.get("device") or {}

    failures = [
        (
            text(failure.get("testIdentifierString")) or "Unknown test",
            text(failure.get("failureText")) or "No failure details",
        )
        for failure in summary.get("testFailures", [])
    ]

    return {
        "title": summary.get("title", "iOSApp"),
        "platform": device.get("platform", "Unknown"),
        "device": device.get("deviceName", "Unknown"),
        "os_version": device.get("osVersion", "Unknown"),
        "passed": int(configuration.get("passedTests", 0) or 0),
        "skipped": int(configuration.get("skippedTests", 0) or 0),
        "failed": int(configuration.get("failedTests", 0) or 0),
        "failures": failures,
    }


def read_xunit(path, environment):
    path = Path(path)
    candidates = (
        path,
        path.with_name(f"{path.stem}-swift-testing{path.suffix}"),
    )
    result_paths = [candidate for candidate in candidates if candidate.is_file()]
    if not result_paths:
        raise FileNotFoundError(path)

    cases = []
    for result_path in result_paths:
        root = ET.parse(result_path).getroot()
        cases.extend(root.findall(".//testcase"))

    failures = []
    skipped = 0

    for case in cases:
        failed = case.find("failure")
        error = case.find("error")
        skipped_case = case.find("skipped")

        if failed is not None or error is not None:
            detail = failed if failed is not None else error
            identifier = ".".join(
                part for part in (case.get("classname"), case.get("name")) if part
            )
            failures.append(
                (
                    identifier or "Unknown test",
                    text(detail.get("message") or detail.text) or "No failure details",
                )
            )
        elif skipped_case is not None:
            skipped += 1

    return {
        **environment,
        "passed": len(cases) - len(failures) - skipped,
        "skipped": skipped,
        "failed": len(failures),
        "failures": failures,
    }


def print_summary(summary, has_results, test_outcome):
    passed = summary["passed"]
    skipped = summary["skipped"]
    failed = summary["failed"]
    total = passed + skipped + failed

    print("===== Test Results Summary =====")
    print("----- Failed Tests -----")
    if summary["failures"]:
        for identifier, details in summary["failures"]:
            print(f'✘ {identifier}\t"{details}"')
    elif has_results:
        print("✅ No failed tests")
    else:
        print("No test results were generated.")

    print()
    print("───────────────💻 Environment ───────────────")
    print("┌──────────────────────┬────────────────────────────────┐")
    for label, key in (
        ("Title", "title"),
        ("Platform", "platform"),
        ("Device", "device"),
        ("OS Version", "os_version"),
    ):
        print(f"│ {label:<20} │ {text(summary[key]):<30} │")
    print("└──────────────────────┴────────────────────────────────┘")

    print()
    print("───────────────📊 Test Counts ───────────────")
    print("┌─────────────┬──────────┐")
    for label, count in (
        ("Passed", passed),
        ("Skipped", skipped),
        ("Failed", failed),
        ("Total", total),
    ):
        print(f"│ {label:<11} │ {count:>8} │")
    print("└─────────────┴──────────┘")

    if failed > 0:
        print(f"\n❌ Some tests failed ({failed})")
        return 1
    if not has_results or test_outcome != "success":
        print(f"\n❌ Test step did not succeed ({test_outcome})")
        return 1

    print("\n✅ All tests passed")
    return 0


def main():
    parser = argparse.ArgumentParser()
    inputs = parser.add_mutually_exclusive_group()
    inputs.add_argument("--xcresult-json")
    inputs.add_argument("--xunit")
    parser.add_argument("--title", default="Unknown")
    parser.add_argument("--platform", default="Unknown")
    parser.add_argument("--device", default="Unknown")
    parser.add_argument("--os-version", default="Unknown")
    parser.add_argument("--test-outcome", default="failure")
    args = parser.parse_args()

    environment = {
        "title": args.title,
        "platform": args.platform,
        "device": args.device,
        "os_version": args.os_version,
    }

    try:
        if args.xcresult_json:
            summary = read_xcresult(args.xcresult_json)
        elif args.xunit:
            summary = read_xunit(args.xunit, environment)
        else:
            summary = {
                **environment,
                "passed": 0,
                "skipped": 0,
                "failed": 0,
                "failures": [],
            }
            return print_summary(summary, False, args.test_outcome)
    except (OSError, ValueError, ET.ParseError, TypeError) as error:
        print(f"Could not read test results: {error}", file=sys.stderr)
        summary = {
            **environment,
            "passed": 0,
            "skipped": 0,
            "failed": 0,
            "failures": [],
        }
        return print_summary(summary, False, args.test_outcome)

    return print_summary(summary, True, args.test_outcome)


if __name__ == "__main__":
    raise SystemExit(main())

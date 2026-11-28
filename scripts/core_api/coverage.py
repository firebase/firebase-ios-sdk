#!/usr/bin/env python3
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Line coverage gate for FirebaseCore.

The CoreSwiftUnit suite (FirebaseCore/Tests/SwiftSuite) is the oracle for
reimplementing FirebaseCore in Swift. This tool measures how much of
FirebaseCore's code that suite covers, on macOS, and compares it with the
baseline in FirebaseCore/Tests/APIBaselines/coverage.json.

  measure  Run CoreSwiftUnit with coverage and write the coverage.
  check    Fail if total line coverage dropped by more than the tolerance.
  update   Measure and replace the baseline.

The tests run with `xcodebuild test -enableCodeCoverage YES` and the
CoreSwiftUnit scheme, like the other Core CI jobs. `swift build` can't build
only CoreSwiftUnit's test bundle with SwiftPM's native build system. The line
counts come from `llvm-cov export` of the build's Coverage.profdata, because
`xccov` leaves out the FirebaseCoreInternal Swift files.

The gate compares total line coverage, not per-file coverage, because Swift
files replace the Objective-C files during the port. Per-file numbers are
recorded and printed for reference.
"""

import argparse
import glob
import json
import os
import shutil
import subprocess
import sys

REPO_ROOT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", ".."))
BASELINE = os.path.join(
    REPO_ROOT, "FirebaseCore", "Tests", "APIBaselines", "coverage.json")
TARGET = "CoreSwiftUnit"
SCHEME_DIR = os.path.join(REPO_ROOT, ".swiftpm", "xcode", "xcshareddata",
                          "xcschemes")
SCHEME_SOURCE = os.path.join(REPO_ROOT, "scripts", "spm_test_schemes",
                             TARGET + ".xcscheme")
DEFAULT_DERIVED_DATA = os.path.join(REPO_ROOT, ".build", "core-coverage")

# The directories whose code counts, relative to the repository root. Add the
# Swift implementation's directories here when it lands.
SOURCE_DIRS = [
    "FirebaseCore/Sources",
    "FirebaseCore/Internal/Sources",
]
SOURCE_EXTENSIONS = (".m", ".mm", ".c", ".swift")
# Test utilities that ship in the sources, but aren't product code.
EXCLUDED_SUFFIXES = ("TestUtils.swift",)

DEFAULT_TOLERANCE = 0.5


def run(command, capture=True, stderr=None):
    """Runs a command in the repository root and returns its output."""
    result = subprocess.run(command, cwd=REPO_ROOT, text=True,
                            stdout=subprocess.PIPE if capture else None,
                            stderr=stderr)
    if result.returncode != 0:
        sys.exit("Command failed ({}): {}".format(result.returncode,
                                                  " ".join(command)))
    return result.stdout if capture else ""


def source_files(source_dirs):
    """Returns the source files to measure, relative to the repository."""
    files = []
    for source_dir in source_dirs:
        for root, _, names in os.walk(os.path.join(REPO_ROOT, source_dir)):
            for name in names:
                if (name.endswith(SOURCE_EXTENSIONS)
                        and not name.endswith(EXCLUDED_SUFFIXES)):
                    files.append(os.path.relpath(os.path.join(root, name),
                                                 REPO_ROOT))
    return sorted(files)


def toolchain():
    """Returns the first line of `swift --version`."""
    # The swift-driver version goes to stderr.
    output = run(["xcrun", "swift", "--version"], stderr=subprocess.DEVNULL)
    return output.strip().splitlines()[0]


def xcode_version():
    """Returns the Xcode version, for example "Xcode 26.4 (17E192)"."""
    lines = run(["xcodebuild", "-version"]).strip().splitlines()
    return " ".join(line.replace("Build version ", "(") + ")"
                    if line.startswith("Build version") else line
                    for line in lines[:2])


def run_tests(derived_data, xcodebuild_args):
    """Runs CoreSwiftUnit with coverage, copying its scheme if needed."""
    scheme = os.path.join(SCHEME_DIR, TARGET + ".xcscheme")
    copied_scheme = not os.path.exists(scheme)
    if copied_scheme:
        os.makedirs(SCHEME_DIR, exist_ok=True)
        shutil.copy(SCHEME_SOURCE, scheme)
    # Remove profiles from earlier runs, so only this run's are found.
    shutil.rmtree(os.path.join(derived_data, "Build", "ProfileData"),
                  ignore_errors=True)
    try:
        run(["xcodebuild", "test", "-scheme", TARGET,
             "-destination", "platform=macOS",
             "-enableCodeCoverage", "YES",
             "-derivedDataPath", derived_data,
             "-collect-test-diagnostics", "never"] + xcodebuild_args,
            capture=False)
    finally:
        if copied_scheme:
            os.remove(scheme)
            # Remove the scheme directories too, if they're now empty.
            for directory in (SCHEME_DIR, os.path.dirname(SCHEME_DIR)):
                if not os.listdir(directory):
                    os.rmdir(directory)


def measure(derived_data, xcodebuild_args, source_dirs):
    """Runs the suite with coverage and returns the coverage."""
    run_tests(derived_data, xcodebuild_args)
    profiles = glob.glob(os.path.join(
        derived_data, "Build", "ProfileData", "*", "Coverage.profdata"))
    if not profiles:
        sys.exit("The tests didn't write a coverage profile.")
    binary = os.path.join(derived_data, "Build", "Products", "Debug",
                          TARGET + ".xctest", "Contents", "MacOS", TARGET)
    files = source_files(source_dirs)
    report = json.loads(run(
        ["xcrun", "llvm-cov", "export", "-summary-only",
         "-instr-profile", max(profiles, key=os.path.getmtime), binary]
        + files))

    measured = {}
    for entry in report["data"][0]["files"]:
        path = os.path.relpath(entry["filename"], REPO_ROOT)
        lines = entry["summary"]["lines"]
        measured[path] = {"lines": lines["count"],
                          "covered": lines["covered"]}
    return {
        "toolchain": toolchain(),
        "xcode": xcode_version(),
        "platform": "macOS",
        "suite": TARGET,
        "total": summarize(measured.values()),
        "groups": {
            source_dir: summarize(
                value for path, value in measured.items()
                if path.startswith(source_dir + os.sep))
            for source_dir in source_dirs
        },
        "files": {path: with_percent(value)
                  for path, value in sorted(measured.items())},
    }


def with_percent(counts):
    """Adds the coverage percentage to line counts."""
    percent = 0.0
    if counts["lines"]:
        percent = 100.0 * counts["covered"] / counts["lines"]
    return dict(counts, percent=round(percent, 2))


def summarize(values):
    """Sums line counts."""
    values = list(values)
    return with_percent({
        "lines": sum(value["lines"] for value in values),
        "covered": sum(value["covered"] for value in values),
    })


def compare(baseline, current, tolerance):
    """Prints the differences and returns False if coverage dropped."""
    if baseline["toolchain"] != current["toolchain"]:
        print("Note: the baseline was recorded with {}, not {}. Coverage can "
              "differ slightly between toolchains.".format(
                  baseline.get("xcode", baseline["toolchain"]),
                  current.get("xcode", current["toolchain"])))

    for path in sorted(set(baseline["files"]) | set(current["files"])):
        before = baseline["files"].get(path)
        after = current["files"].get(path)
        if before is None:
            print("  new      {:7.2f}%  {}".format(after["percent"], path))
        elif after is None:
            print("  removed  {:7.2f}%  {}".format(before["percent"], path))
        elif before["percent"] != after["percent"]:
            print("  changed  {:7.2f}% -> {:7.2f}%  {}".format(
                before["percent"], after["percent"], path))

    before = baseline["total"]["percent"]
    after = current["total"]["percent"]
    print("Total line coverage: {:.2f}% (baseline {:.2f}%, tolerance {} "
          "points)".format(after, before, tolerance))
    if after < before - tolerance:
        print("error: line coverage dropped by {:.2f} points.".format(
            before - after))
        return False
    return True


def write_json(path, value):
    with open(path, "w", encoding="utf-8") as file:
        json.dump(value, file, indent=2, sort_keys=True)
        file.write("\n")


def read_json(path):
    with open(path, encoding="utf-8") as file:
        return json.load(file)


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "command", choices=["measure", "check", "update"])
    parser.add_argument(
        "--derived-data-path", default=DEFAULT_DERIVED_DATA,
        help="xcodebuild's derived data path. Defaults to %(default)s.")
    parser.add_argument(
        "--cloned-source-packages-path",
        help="Where xcodebuild finds or clones the package dependencies.")
    parser.add_argument(
        "--xcodebuild-arg", action="append", default=[],
        help="Extra argument for xcodebuild, for example "
             "--xcodebuild-arg=-disableAutomaticPackageResolution. Can be "
             "repeated.")
    parser.add_argument(
        "--source-dir", action="append",
        help="A directory whose code counts, relative to the repository. "
             "Can be repeated. Defaults to {}.".format(", ".join(SOURCE_DIRS)))
    parser.add_argument(
        "--out",
        help="Where `measure` and `check` write the measured coverage.")
    parser.add_argument(
        "--current",
        help="Coverage written by `measure`, for `check`. Measures if not "
             "given.")
    parser.add_argument(
        "--tolerance", type=float, default=DEFAULT_TOLERANCE,
        help="How many points total coverage may drop. Defaults to "
             "%(default)s.")
    args = parser.parse_args()
    source_dirs = args.source_dir or SOURCE_DIRS

    xcodebuild_args = list(args.xcodebuild_arg)
    if args.cloned_source_packages_path:
        xcodebuild_args += ["-clonedSourcePackagesDirPath",
                            args.cloned_source_packages_path]

    if args.command == "check" and args.current:
        current = read_json(args.current)
    else:
        current = measure(os.path.abspath(args.derived_data_path),
                          xcodebuild_args, source_dirs)

    if args.command == "measure":
        if args.out:
            write_json(args.out, current)
        else:
            print(json.dumps(current, indent=2, sort_keys=True))
    elif args.command == "update":
        write_json(BASELINE, current)
        print("Updated {} ({:.2f}%).".format(
            os.path.relpath(BASELINE, REPO_ROOT),
            current["total"]["percent"]))
    else:
        if args.out:
            write_json(args.out, current)
        if not compare(read_json(BASELINE), current, args.tolerance):
            sys.exit(1)


if __name__ == "__main__":
    main()

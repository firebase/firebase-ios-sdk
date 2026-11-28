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

  measure  Build CoreSwiftUnit with coverage, run it, and write the coverage.
  check    Fail if total line coverage dropped by more than the tolerance.
  update   Measure and replace the baseline.

The gate compares total line coverage, not per-file coverage, because Swift
files replace the Objective-C files during the port. Per-file numbers are
recorded and printed for reference.
"""

import argparse
import glob
import json
import os
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", ".."))
BASELINE = os.path.join(
    REPO_ROOT, "FirebaseCore", "Tests", "APIBaselines", "coverage.json")
TARGET = "CoreSwiftUnit"

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


def run(command, env=None, capture=True):
    """Runs a command in the repository root and returns its output."""
    result = subprocess.run(command, cwd=REPO_ROOT, env=env, text=True,
                            stdout=subprocess.PIPE if capture else None)
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
    output = run(["xcrun", "swift", "--version"])
    return output.strip().splitlines()[0]


def measure(build_args, source_dirs):
    """Builds and runs the suite with coverage and returns the coverage."""
    build = ["swift", "build", "--target", TARGET, "--enable-code-coverage"]
    build += build_args
    run(build, capture=False)
    bin_path = run(build + ["--show-bin-path"]).strip().splitlines()[-1]
    bundle = os.path.join(bin_path, TARGET + ".xctest")
    binary = os.path.join(bundle, "Contents", "MacOS", TARGET)

    with tempfile.TemporaryDirectory() as profile_dir:
        env = dict(os.environ)
        env["LLVM_PROFILE_FILE"] = os.path.join(profile_dir, "%p.profraw")
        run(["xcrun", "xctest", bundle], env=env, capture=False)
        profiles = glob.glob(os.path.join(profile_dir, "*.profraw"))
        if not profiles:
            sys.exit("The tests didn't write any coverage profiles.")
        profdata = os.path.join(profile_dir, "merged.profdata")
        run(["xcrun", "llvm-profdata", "merge", "-sparse", "-o", profdata]
            + profiles)
        files = source_files(source_dirs)
        report = json.loads(run(
            ["xcrun", "llvm-cov", "export", "-summary-only",
             "-instr-profile", profdata, binary] + files))

    measured = {}
    for entry in report["data"][0]["files"]:
        path = os.path.relpath(entry["filename"], REPO_ROOT)
        lines = entry["summary"]["lines"]
        measured[path] = {"lines": lines["count"],
                          "covered": lines["covered"]}
    return {
        "toolchain": toolchain(),
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
                  baseline["toolchain"], current["toolchain"]))

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
    with open(path, "w") as file:
        json.dump(value, file, indent=2, sort_keys=True)
        file.write("\n")


def read_json(path):
    with open(path) as file:
        return json.load(file)


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "command", choices=["measure", "check", "update"])
    parser.add_argument(
        "--build-arg", action="append", default=[],
        help="Extra argument for `swift build`, for example "
             "--build-arg=--disable-sandbox. Can be repeated.")
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

    if args.command == "check" and args.current:
        current = read_json(args.current)
    else:
        current = measure(args.build_arg, source_dirs)

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

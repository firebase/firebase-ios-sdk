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

"""Fails if xcodebuild logs have compiler warnings in this repository's files.

The SPM CI jobs build SDK sources and test targets with xcodebuild, which
doesn't fail on warnings. `pod lib lint` does, so a warning can pass SPM CI and
break CocoaPods CI later, and code that only SPM builds isn't checked for
warnings anywhere else. See #9144.

The script reads the raw logs that scripts/build.sh writes:
xcodebuild-test.log or xcodebuild-build.log, plus xcodebuild-*-retry.log if
xcodebuild was retried. It reports compiler warnings that point to a file in
this repository, in SDK sources and tests alike. Warnings in dependencies are
ignored.

Xcode doesn't recompile up-to-date files, so a log only has warnings for files
that were compiled in that run.

Usage: scripts/check_xcodebuild_warnings.py [--ignore-deprecations] [LOG ...]
"""

import argparse
import os
import re
import sys

# Header line that xcodebuild prints before the output of each build task, for
# example:
#   SwiftCompile normal arm64 /path/Foo.swift (in target 'AuthUnit' from
#   project 'Firebase')
TASK_HEADER = re.compile(r"^\S.* \(in target '([^']+)' from project '[^']+'\)$")

# Compiler diagnostic, for example:
#   /path/Foo.swift:12:5: warning: 'bar()' is deprecated
WARNING = re.compile(r"^(/[^:]+):(\d+):(\d+): warning: (.*)$")

# Deprecation warnings from Swift ("'foo' is deprecated", "'foo' was deprecated
# in iOS 13.0") and Clang ("[-Wdeprecated-declarations]").
DEPRECATION = re.compile(r" (is|was) deprecated|\[-Wdeprecated[\w-]*\]")

DEFAULT_LOGS = [
  "xcodebuild-test.log",
  "xcodebuild-test-retry.log",
  "xcodebuild-build.log",
  "xcodebuild-build-retry.log",
]


def find_warnings(lines, repo_root, ignore_deprecations):
  """Returns (file, line, column, message, target) for each warning."""
  # Package checkouts, when SwiftPM rather than Xcode resolved them.
  excluded_dirs = [os.path.join(repo_root, ".build") + os.sep]
  warnings = []
  seen = set()
  target = None
  for line in lines:
    header = TASK_HEADER.match(line)
    if header:
      target = header.group(1)
      continue
    match = WARNING.match(line)
    if not match:
      continue
    if ignore_deprecations and DEPRECATION.search(match.group(4)):
      continue
    path = os.path.realpath(match.group(1))
    if not path.startswith(repo_root + os.sep):
      continue
    if any(path.startswith(d) for d in excluded_dirs):
      continue
    relative_path = os.path.relpath(path, repo_root)
    warning = (relative_path, int(match.group(2)), int(match.group(3)),
               match.group(4))
    # Swift prints some warnings more than once, for example once per
    # architecture or once from each of two build tasks.
    if warning in seen:
      continue
    seen.add(warning)
    warnings.append(warning + (target,))
  return warnings


def main():
  parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
  parser.add_argument(
    "logs", nargs="*", metavar="LOG",
    help="raw xcodebuild logs (default: whichever of "
    f"{', '.join(DEFAULT_LOGS)} exist)")
  parser.add_argument(
    "--ignore-deprecations", action="store_true",
    help="ignore deprecation warnings, for tests of deprecated APIs")
  args = parser.parse_args()

  logs = args.logs or [log for log in DEFAULT_LOGS if os.path.exists(log)]
  if not logs:
    print("error: no xcodebuild log found. Run scripts/build.sh first.",
          file=sys.stderr)
    return 1

  repo_root = os.path.realpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

  warnings = []
  for log in logs:
    try:
      with open(log, encoding="utf-8", errors="replace") as f:
        lines = [line.rstrip("\r\n") for line in f]
    except FileNotFoundError:
      print(f"error: {log} not found.", file=sys.stderr)
      return 1
    for warning in find_warnings(lines, repo_root, args.ignore_deprecations):
      if warning not in warnings:
        warnings.append(warning)

  if not warnings:
    print("No compiler warnings in this repository's files "
          f"({', '.join(logs)}).")
    return 0

  in_actions = os.environ.get("GITHUB_ACTIONS") == "true"
  for path, line, column, message, target in warnings:
    print(f"{path}:{line}:{column}: warning: {message} [{target}]",
          file=sys.stderr)
    if in_actions:
      # Shows the warning on the PR's changed files.
      escaped = (message.replace("%", "%25").replace("\r", "%0D")
                 .replace("\n", "%0A"))
      print(f"::error file={path},line={line},col={column}::{escaped}")
  print(file=sys.stderr)
  print(f"error: found {len(warnings)} compiler warning(s). Fix them, or for "
        "tests of deprecated APIs, set ignore_deprecation_warnings in the "
        "workflow that calls _spm.yml.", file=sys.stderr)
  return 1


if __name__ == "__main__":
  sys.exit(main())

#!/usr/bin/env python

# Copyright 2018 Google
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

"""Verifies that all tests are a part of the project file.
"""

from __future__ import print_function
import os
import os.path
import re
import sys


# Tests that are known not to compile in Xcode and can't be added there.
EXCLUDED = frozenset([
])


def Main():
  """Runs the style check."""

  tests = FindTestFiles("Firestore/Example/Tests", "Firestore/core/test")
  problems = CheckProject(
      "Firestore/Example/Firestore.xcodeproj/project.pbxproj", tests)

  if problems:
    Error("Test files exist that are unreferenced in Xcode project files:")
    for problem in problems:
      Error(problem)
    sys.exit(1)

  sys.exit(0)


def FindTestFiles(*test_dirs):
  """Searches the given source roots for test files.

  Args:
    *test_dirs: A list of directories containing test sources.

  Returns:
    A list of test source filenames.
  """

  test_file_pattern = re.compile(r"(?:Tests?\.mm?|_test\.(?:cc|mm))$")

  result = []
  for test_dir in test_dirs:
    for root, dirs, files in os.walk(test_dir):
      del dirs  # unused
      for basename in files:
        filename = os.path.join(root, basename)
        if filename not in EXCLUDED and test_file_pattern.search(basename):
          result.append(filename)
  return result


def CheckProject(project_file, test_files):
  """Checks the given project file for tests in the given test_dirs.

  Args:
    project_file: The path to an Xcode pbxproj file.
    test_files: A list of all tests source files in the project.

  Returns:
    A sorted list of filenames that aren't referenced in the project_file.
  """

  # An dict of basename to filename
  basenames = {os.path.basename(f): f for f in test_files}

  file_list_pattern = re.compile(r"/\* (\S+) in Sources \*/")
  with open(project_file, "r") as fd:
    for line in fd:
      line = line.rstrip()
      m = file_list_pattern.search(line)
      if m:
        basename = m.group(1)
        if basename in basenames:
          del basenames[basename]

  return sorted(basenames.values())


def Error(message, *args):
  message %= args
  print(message, file=sys.stderr)


if __name__ == "__main__":
  Main()

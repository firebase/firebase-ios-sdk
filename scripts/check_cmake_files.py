#!/usr/bin/env python

# Copyright 2019 Google
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

"""Checks that source files are mentioned in CMakeLists.txt.

Also checks that files mentioned in CMakeLists.txt exist on the filesystem.

Note that this check needs to be able to run before anything has been built, so
generated files must be excluded from the check. Add a "# NOLINT(generated)"
comment to any line mentioning such a file to ensure they don't falsely trigger
errors. This only needs to be done once within a file.
"""

import argparse
import collections
import os
import re
import sys

from lib import git

# Directories relative to the repo root that will be scanned by default if no
# arguments are passed.
_DEFAULT_DIRS = [
    'Firestore/core',
    'Firestore/Source'
]

# When scanning the filesystem, look for specific files or files with these
# extensions.
_INCLUDE_FILES = {'CMakeLists.txt'}
_INCLUDE_EXTENSIONS = {'.c', '.cc', '.h', '.m', '.mm'}

# When scanning the filesystem, exclude any files or directories with these
# names.
_EXCLUDE_DIRS = {'third_party', 'Pods', 'Protos'}

_verbose = False


def main(args):
  global _verbose

  parser = argparse.ArgumentParser(
      description='Check CMakeLists.txt file membership.')
  parser.add_argument('--verbose', '-v', action='store_true',
                      help='Run verbosely')
  parser.add_argument('filenames', nargs='*', metavar='file_or_dir',
                      help='Files and directories to scan')
  args = parser.parse_args(args)
  if args.verbose:
    _verbose = True

  scan_filenames = args.filenames
  if not scan_filenames:
    scan_filenames = default_args()

  filenames = find_source_files(scan_filenames)
  groups = group_by_cmakelists(filenames)
  errors = find_all_errors(groups)
  trace('checked %d files' % len(filenames))
  sys.exit(1 if errors else 0)


def default_args():
  """Returns a default list of directories to scan.
  """
  toplevel = git.get_repo_root()

  return [os.path.join(toplevel, dirname) for dirname in _DEFAULT_DIRS]


def find_source_files(roots):
  """Finds source files on the filesystem.

  Args:
    roots: A list of files or directories

  Returns:
    A list of filenames found in the roots, excluding those that are
    uninteresting.

  """
  result = []

  for root in roots:
    for parent, dirs, files in os.walk(root, topdown=True):
      # Prune directories known to be uninteresting
      dirs[:] = [d for d in dirs if d not in _EXCLUDE_DIRS]

      for filename in files:
        if filename in _INCLUDE_FILES or is_source_file(filename):
          result.append(os.path.join(parent, filename))

  return result


_filename_pattern = re.compile(r'\b([A-Za-z0-9_/+]+\.)+(?:c|cc|h|m|mm)\b')
_comment_pattern = re.compile(r'^(\s*)#')
_check_pattern = re.compile(r'^\s*check_[A-Za-z0-9_]+\(.*\)$')
_nolint_pattern = re.compile(r'NOLINT')


def read_listed_source_files(filename):
  """Reads the contents of the given filename and finds all the filenames it
  finds in the file.

  Args:
    filename: A filename to read, typically some path to a CMakeLists.txt file.

  Returns:
    A pair of lists. The first list contains filenames mentioned in the file.
    The second contains files that have been ignored (by marking them NOLINT)
    in the file. Elements from the second list might also be present in the
    first list.
  """
  found = []
  ignored = []
  parent = os.path.dirname(filename)

  with open(filename, 'r') as fd:
    for line in fd.readlines():
      # Simple hack to exclude files mentioned in CMake checks
      if _check_pattern.match(line):
        continue

      ignore = bool(_nolint_pattern.search(line))

      if not ignore:
        # Exclude comments, but only on regular lines. This allows files to
        # include files in comments that mark them NOLINT.
        m = _comment_pattern.match(line)
        if m:
          line = m.group(1)

      for m in _filename_pattern.finditer(line):
        listed_filename = os.path.join(parent, m.group(0))
        if ignore:
          trace('ignoring %s' % listed_filename)
          ignored.append(listed_filename)
        else:
          found.append(listed_filename)

  found.sort()
  ignored.sort()
  return found, ignored


class Group(object):
  """A comparison group.

  Groups include the location of a CMakeLists.txt file along with files that
  were found on the filesystem that should be mentioned in the file, files that
  were found in the CMakeLists.txt file, and any files that should be ignored.
  """

  def __init__(self):
    self.list_file = None
    self.fs_files = []
    self.list_files = []
    self.ignored_files = []

  def shorten(self):
    """Shorten filenames to make them relative to the directory containing the
    CMakeLists.txt file and make the file lists into sets.
    """
    prefix = os.path.dirname(self.list_file) + '/'

    self.fs_files = self._remove_prefix(prefix, self.fs_files)
    self.list_files = self._remove_prefix(prefix, self.list_files)
    self.ignored_files = self._remove_prefix(prefix, self.ignored_files)

  def _remove_prefix(self, prefix, filenames):
    result = []

    for filename in filenames:
      if not filename.startswith(prefix):
        raise Exception('Filename %s not in prefix %s' % (filename, prefix))

      result.append(filename[len(prefix):])

    return set(result)

  def __repr__(self):
    def files(items):
      return repr(sorted(list(items)))

    return """<Group %s
    fs=%s
    listed=%s
    ignored=%s>""" % (self.list_file,
                      files(self.fs_files),
                      files(self.list_files),
                      files(self.ignored_files))


def group_by_cmakelists(filenames):
  """Groups the given filenames by the nearest CMakeLists.txt

  Args:
    filenames: A list of filenames found on the filesystem.

  Returns:
    A list of filled-out Groups for evaluation.
  """
  filename_set = set(filenames)

  groups = collections.defaultdict(Group)

  for filename in filenames:
    if is_source_file(filename):
      for cmake_list in possible_cmake_lists_files(filename):
        if cmake_list in filename_set:
          groups[cmake_list].fs_files.append(filename)
          break

    elif os.path.basename(filename) == 'CMakeLists.txt':
      g = groups[filename]
      g.list_file = filename
      g.list_files, g.ignored_files = read_listed_source_files(filename)

  return sorted(list(groups.values()))


def find_all_errors(groups):
  """Finds errors in the given groups.

  Args:
    groups: A list of groups. Each group is shortened.

  Returns:
    A count of errors encountered; errors information is printed for the user.
  """
  errors = 0
  for group in groups:
    group.shorten()
    errors += find_errors(group)

  return errors


def find_errors(group):
  """Evaluates whether or not a group has any errors.
  """
  in_both = group.fs_files.intersection(group.list_files)
  in_both = in_both | group.ignored_files

  just_fs = group.fs_files - in_both
  just_list = group.list_files - in_both

  if just_fs or just_list:
    sys.stderr.write('%s had errors:\n' % group.list_file)

    for filename in sorted(just_fs):
      sys.stderr.write('  %s: missing from CMakeLists.txt\n' % filename)

    for filename in sorted(just_list):
      sys.stderr.write('  %s: missing from filesystem\n' % filename)

  return len(just_fs) + len(just_list)


def is_source_file(filename):
  ext = os.path.splitext(filename)[1]
  return ext in _INCLUDE_EXTENSIONS


def possible_cmake_lists_files(filename):
  """Finds CMakeLists.txt files that might apply to the given filename.

  Args:
    filename: A source file

  Yields:
    A sequence of CMakeLists.txt filenames that might govern the source file,
    starting in the directory containing the given filename and working up
    toward the filesystem root. The filenames may point to files that don't
    exist.
  """
  while filename:
    filename = os.path.dirname(filename)
    yield os.path.join(filename, 'CMakeLists.txt')


def trace(line):
  if _verbose:
    sys.stderr.write('%s\n' % line)


if __name__ == '__main__':
  main(sys.argv[1:])

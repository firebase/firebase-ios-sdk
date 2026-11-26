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

"""Verifies that every test source file is compiled by an SPM target.

A test source file passes if a target in the root Package.swift compiles it,
or if an entry in scripts/spm_test_parity_allowlist.txt covers it. The check
fails if:

  * a test source file is neither compiled by SPM nor allowlisted;
  * an allowlist entry matches no test source file (the entry is stale);
  * an allowlist entry matches a file that SPM compiles (delete the entry).
    Entries in the `separate-package` category are exempt from this rule,
    because the root manifest includes some of those targets only with some
    toolchains.

The SPM target model comes from `swift package dump-package`, which evaluates
the manifest without resolving dependencies. Test source files come from
`git ls-files`, so untracked files and build outputs are ignored.

Run from anywhere in the repo:

  scripts/check_spm_test_parity.py
"""

import argparse
import collections
import json
import os
import re
import subprocess
import sys


ALLOWLIST = 'scripts/spm_test_parity_allowlist.txt'

SOURCE_EXTENSIONS = ('.m', '.mm', '.swift', '.c', '.cc', '.cpp')

# Allowlist categories and what they mean.
CATEGORIES = collections.OrderedDict([
    ('xcodeproj', 'compiled by a checked-in Xcode project that uses the '
                  'local package'),
    ('cmake', 'Firestore C++ built by CMake'),
    ('separate-package', 'compiled by another Package.swift in this repo'),
    ('cocoapods', 'tests CocoaPods packaging itself; removed with CocoaPods'),
    ('gap', 'compiled only by CocoaPods today; must be ported to SPM'),
    ('dead', 'compiled by nothing; pending deletion or revival'),
    ('phase6', 'Firestore tests built by the CocoaPods Firestore workspace; '
               'deferred to Phase 6'),
])

# Categories whose entries may match files that the root package compiles.
# The root manifest adds the GeminiLanguageModel targets only when the
# compiler supports them, so whether SPM compiles those files depends on the
# toolchain that runs this script.
EXEMPT_FROM_COMPILED_CHECK = frozenset(['separate-package'])

# Repo tooling, not SDK code. These directories hold their own Swift packages
# with their own tests and CI.
EXCLUDED_PREFIXES = ('ReleaseTooling/', 'scripts/')

# Directories whose sources are all test code, in addition to directories
# matched by TEST_SEGMENT.
TEST_DIR_PREFIXES = (
    'Firestore/Example/',
    'Firestore/core/test/',
    'Firestore/fuzzing/',
    'IntegrationTesting/',
    'SharedTestUtilities/',
    'SwiftPMTests/',
    'SymbolCollisionTest/',
)

# Matches a directory name that holds test code, such as `Tests`,
# `UnitTests`, or `UnitTestsSwift`.
TEST_SEGMENT = re.compile(r'^(Unit)?Tests')


def main():
  parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
  parser.add_argument(
      '--package-json',
      help='Read `swift package dump-package` output from this file instead '
           'of running it.')
  parser.add_argument(
      '--allowlist', default=ALLOWLIST,
      help='Allowlist file, relative to the repo root (default: %(default)s).')
  args = parser.parse_args()

  package_json = args.package_json and os.path.abspath(args.package_json)
  os.chdir(git_top_level())

  if package_json:
    with open(package_json) as fd:
      package = json.load(fd)
  else:
    package = dump_package()

  test_files = find_test_files()
  compiled = compiled_files(package, test_files)
  entries = read_allowlist(args.allowlist)
  sys.exit(check(test_files, compiled, entries, args.allowlist))


def git_top_level():
  return subprocess.check_output(
      ['git', 'rev-parse', '--show-toplevel'], universal_newlines=True).strip()


def dump_package():
  """Returns the root package's manifest as a dict."""
  proc = subprocess.run(
      ['swift', 'package', 'dump-package'],
      stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
  if proc.returncode != 0:
    error('`swift package dump-package` failed:')
    error(proc.stderr)
    sys.exit(2)
  return json.loads(proc.stdout)


def is_test_dir(path):
  """Returns True if every source file under path is test code.

  Args:
    path: A repo-relative directory path.
  """
  path = path.rstrip('/') + '/'
  if path.startswith(EXCLUDED_PREFIXES):
    return False
  if path.startswith(TEST_DIR_PREFIXES):
    return True
  return any(TEST_SEGMENT.match(segment) for segment in path.split('/'))


def find_test_files():
  """Returns the set of tracked test source files that exist on disk."""
  patterns = ['*' + ext for ext in SOURCE_EXTENSIONS]
  output = subprocess.check_output(
      ['git', 'ls-files', '-z', '--'] + patterns, universal_newlines=True)
  return set(
      f for f in output.split('\0')
      if f and os.path.isfile(f) and is_test_dir(os.path.dirname(f)))


def target_root(target):
  """Returns the repo-relative directory of a target's sources."""
  if target.get('path'):
    return os.path.normpath(target['path'])

  # SwiftPM's default target locations.
  if target['type'] == 'test':
    parents = ['Tests', 'Sources', 'Source', 'src', 'srcs']
  else:
    parents = ['Sources', 'Source', 'src', 'srcs']
  for parent in parents:
    candidate = os.path.join(parent, target['name'])
    if os.path.isdir(candidate):
      return candidate
  return os.path.join(parents[0], target['name'])


def is_within(path, directory):
  return path == directory or path.startswith(directory + '/')


def compiled_files(package, candidates):
  """Returns the candidate files that SPM targets compile.

  Considers every test target, plus regular targets that live in a test
  directory (for example, SharedTestUtilities).

  Args:
    package: The output of `swift package dump-package`.
    candidates: The set of files to consider.

  Returns:
    A dict mapping each compiled file to the names of targets that compile it.
  """
  result = collections.defaultdict(list)
  for target in package['targets']:
    kind = target['type']
    if kind == 'binary' or kind == 'plugin':
      continue
    root = target_root(target)
    if kind != 'test' and not is_test_dir(root):
      continue

    def resolve(relative):
      return os.path.normpath(os.path.join(root, relative))

    sources = target.get('sources')
    includes = [root] if sources is None else [resolve(s) for s in sources]
    excludes = [resolve(e) for e in target.get('exclude') or []]
    excludes += [resolve(r['path']) for r in target.get('resources') or []]

    for path in candidates:
      included = any(is_within(path, i) for i in includes)
      if included and not any(is_within(path, e) for e in excludes):
        result[path].append(target['name'])
  return result


class Entry(object):
  """An allowlist entry."""

  def __init__(self, pattern, category, reason, line_number):
    self.pattern = pattern
    self.category = category
    self.reason = reason
    self.line_number = line_number
    self.regex = glob_to_regex(pattern)

  def matches(self, path):
    return self.regex.match(path) is not None


def glob_to_regex(pattern):
  """Compiles a path glob into a regex that matches whole paths.

  `**` matches any number of directories, `*` and `?` match within one path
  component, and a trailing `/` matches everything under a directory.

  Args:
    pattern: A repo-relative glob.

  Returns:
    A compiled regex.
  """
  if pattern.endswith('/'):
    pattern += '**'
  result = ''
  i = 0
  while i < len(pattern):
    if pattern.startswith('**/', i):
      result += '(?:.*/)?'
      i += 3
    elif pattern.startswith('**', i):
      result += '.*'
      i += 2
    elif pattern[i] == '*':
      result += '[^/]*'
      i += 1
    elif pattern[i] == '?':
      result += '[^/]'
      i += 1
    else:
      result += re.escape(pattern[i])
      i += 1
  return re.compile(result + r'\Z')


def read_allowlist(filename):
  """Parses the allowlist file.

  Each entry is a line `<glob>  # <category>: <reason>`. Blank lines and lines
  starting with `#` are ignored.

  Args:
    filename: The allowlist path.

  Returns:
    A list of Entry objects.
  """
  entries = []
  problems = []
  with open(filename) as fd:
    for line_number, line in enumerate(fd, 1):
      line = line.strip()
      if not line or line.startswith('#'):
        continue
      pattern, _, comment = line.partition('#')
      pattern = pattern.strip()
      category, _, reason = comment.partition(':')
      category = category.strip()
      reason = reason.strip()
      location = '%s:%d' % (filename, line_number)
      if ' ' in pattern or '\t' in pattern:
        problems.append('%s: pattern contains whitespace: %s' %
                        (location, pattern))
      elif category not in CATEGORIES:
        problems.append('%s: expected `<glob>  # <category>: <reason>` with '
                        'a category in [%s]: %s' %
                        (location, ', '.join(CATEGORIES), line))
      elif not reason:
        problems.append('%s: missing reason: %s' % (location, line))
      else:
        entries.append(Entry(pattern, category, reason, line_number))

  if problems:
    error('Malformed allowlist entries:')
    for problem in problems:
      error('  ' + problem)
    sys.exit(2)
  return entries


def check(test_files, compiled, entries, allowlist):
  """Compares test files with SPM targets and the allowlist.

  Args:
    test_files: The set of test source files.
    compiled: A dict mapping files compiled by SPM to target names.
    entries: The allowlist entries.
    allowlist: The allowlist path, for messages.

  Returns:
    The exit code.
  """
  matches = {entry: sorted(f for f in test_files if entry.matches(f))
             for entry in entries}

  allowlisted = {}
  for entry in entries:
    for path in matches[entry]:
      allowlisted.setdefault(path, entry)

  orphans = sorted(f for f in test_files
                   if f not in compiled and f not in allowlisted)
  stale = [e for e in entries if not matches[e]]
  redundant = [
      (e, [f for f in matches[e] if f in compiled])
      for e in entries if e.category not in EXEMPT_FROM_COMPILED_CHECK]
  redundant = [(e, files) for e, files in redundant if files]

  counts = collections.Counter()
  for path in test_files:
    if path in compiled:
      counts['compiled by SPM'] += 1
    elif path in allowlisted:
      counts[allowlisted[path].category] += 1

  print('SPM test parity: %d test source files' % len(test_files))
  for label in ['compiled by SPM'] + list(CATEGORIES):
    print('  %-17s %5d' % (label, counts[label]))
  sys.stdout.flush()

  failed = False
  if orphans:
    failed = True
    error('')
    error('These test files are not compiled by any SPM target in '
          'Package.swift. Add them to a test target, or, if they must stay '
          'out of SPM, add an entry with a reason to %s:' % allowlist)
    for path in orphans:
      error('  ' + path)

  if stale:
    failed = True
    error('')
    error('These %s entries match no test file. Delete them:' % allowlist)
    for entry in stale:
      error('  line %d: %s' % (entry.line_number, entry.pattern))

  if redundant:
    failed = True
    error('')
    error('These %s entries match files that SPM now compiles. Narrow or '
          'delete them:' % allowlist)
    for entry, files in redundant:
      error('  line %d: %s' % (entry.line_number, entry.pattern))
      for path in files:
        error('    %s (%s)' % (path, ', '.join(compiled[path])))

  if failed:
    return 1
  print('OK')
  return 0


def error(message):
  print(message, file=sys.stderr)


if __name__ == '__main__':
  main()

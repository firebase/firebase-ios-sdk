#! /usr/bin/env python

# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0(the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http:  // www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Check no absl reference are added to Firestore/core/src/api header files.

Absl references in core/src/api public interface will cause link error for
the Unity SDK, when it is built from google3.
"""

# TODO(b/192129206) : Remove this check once Unity SDK is built from Github.
import argparse
import logging
import six
import subprocess

from lib import command_trace

_logger = logging.getLogger('absl_check')


def diff_with_absl(revision, patterns):
  """Finds diffs containing 'absl' since a revision from specified path
  pattern.
  """
  # git command to print all diffs that has 'absl' in it.
  command = ['git', 'diff', '-G', 'absl', revision, '--']
  command.extend(patterns)
  _logger.debug(command)
  return six.ensure_text(subprocess.check_output(command))


def main():
  patterns = ['Firestore/core/src/api/*.h']
  parser = argparse.ArgumentParser(
      description='Check Absl usage in %s' % patterns)
  parser.add_argument(
      '--dry-run',
      '-n',
      action='store_true',
      help='Show what the linter would do without doing it')
  parser.add_argument(
      'rev',
      nargs='?',
      help='A single revision that specifies a point in time '
      'from which to look for changes. Defaults to '
      'origin/master.')
  args = command_trace.parse_args(parser)

  dry_run = False
  if args.dry_run:
    dry_run = True
    _logger.setLevel(logging.DEBUG)

  revision = 'origin/master' if not args.rev else args.rev
  _logger.debug('Checking %s absl usage against %s' %
                (patterns, revision))
  diff = diff_with_absl(revision, patterns)

  # Check for changes adding new absl references only.
  lines = [line for line in diff.splitlines()
           if line.startswith('+') and 'absl::' in line]
  if lines:
      _logger.error(
          'Found a change introducing reference to absl under %s'
          % patterns)
      for line in lines:
          _logger.error(' %s' % line)
      if not dry_run:
          exit(-1)


if __name__ == '__main__':
  main()

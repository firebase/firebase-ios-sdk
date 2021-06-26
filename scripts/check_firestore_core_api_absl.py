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
  command = ['git', 'diff', '-z', '-G', 'absl', revision, '--']
  command.extend(patterns)
  command_trace.log(command)
  return six.ensure_text(subprocess.check_output(command))


def main():
  parser = argparse.ArgumentParser(description='Lint source files.')
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
    command_trace.enable_tracing()

  revision = 'origin/master' if (not args.rev) else args.rev
  _logger.debug('Checking Firestore/core/src/api absl usage against %s' %
                revision)
  diff = diff_with_absl(revision, ['Firestore/core/src/api/*.h'])

  # Check for changes adding new absl references only.
  found = False
  for line in diff.splitlines():
    # Additions start with '+'
    if line.startswith('+') and line.find('absl::') >= 0:
      # Found a change introducing a reference to absl
      _logger.error(
          'Found a change introducing reference to absl under'
          'Firestore/core/api:'
      )
      _logger.error('  %s' % line)
      _logger.error('')
      found = True

  if found and (not dry_run):
    exit(-1)


if __name__ == '__main__':
  main()

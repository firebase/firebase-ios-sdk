# Copyright 2019 Google LLC
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

import os
import subprocess

from lib import command_trace
from lib import source


def find_changed_or_files(all, rev_or_files, patterns):
  """Finds files.

  Args:
    all: Force finding all files.
    rev_or_files: A single revision, a list of files, or empty.
    patterns: A list of git matching patterns

  Returns:
    Files that match.

    If rev_or_files is a single revision, the result is all files that match
    the patterns that have changed since the revision.

    If rev_or_files is a list of files, the result is all the files that match
    that list of files. The files can be patterns.

    If rev_or_files is empty, the result is all the files that match patterns.
  """
  if all:
    return find_files(patterns)

  if not rev_or_files:
    return find_changed('origin/main', patterns)

  if len(rev_or_files) == 1 and is_revision(rev_or_files[0]):
    return find_changed(rev_or_files[0], patterns)
  else:
    return find_files(rev_or_files)


def is_revision(word):
  """Returns true if the given word is a revision name according to git."""
  command = ['git', 'rev-parse', word, '--']
  with open(os.devnull, 'w') as dev_null:
    command_trace.log(command)
    rc = subprocess.call(command, stdout=dev_null, stderr=dev_null)
    return rc == 0


def find_changed(revision, patterns):
  """Finds files changed since a revision."""

  # Always include -- indicate that revision is known to be a revision, even
  # if no patterns follow.
  command = ['git', 'diff', '-z', '--name-only', '--diff-filter=ACMR',
             revision, '--']
  command.extend(patterns)
  command.extend(standard_exclusions())
  return _null_split_output(command)


def find_files(patterns=None):
  """Finds files matching the given patterns using git ls-files."""
  command = ['git', 'ls-files', '-z', '--']
  if patterns:
    command.extend(patterns)
  command.extend(standard_exclusions())
  return _null_split_output(command)


def find_lines_matching(pattern, sources=None):
  command = [
      'git', 'grep',
      '-n',  # show line numbers
      '-I',  # exclude binary files
      pattern,
      '--'
  ]
  if sources:
    command.extend(sources)
  command.extend(standard_exclusions())

  command_trace.log(command)

  bufsize = 4096
  proc = subprocess.Popen(command, bufsize=bufsize, stdout=subprocess.PIPE)
  result = []
  try:
    while proc.poll() is None:
      result.append(proc.stdout.read(bufsize))
  except KeyboardInterrupt:
    proc.terminate()
    proc.wait()

  return b''.join(result).decode('utf8', errors='replace')


def make_patterns(dirs):
  """Returns a list of git match patterns for the given directories."""
  return ['%s/**' % d for d in dirs]


def make_exclusions(dirs):
  return [':(exclude)' + d for d in dirs]


def standard_exclusions():
  result = make_exclusions(source.IGNORE)
  result.append(':(exclude)**/third_party/**')
  return result


def is_within_repo():
  """Returns whether the current working directory is within a git repo."""
  try:
    subprocess.check_output(['git', 'status'])
    return True
  except subprocess.CalledProcessError:
    return False


def get_repo_root():
  """Returns the absolute path to the root of the current git repo."""
  command = ['git', 'rev-parse', '--show-toplevel']
  return subprocess.check_output(command, text=True, errors='replace').rstrip()


def _null_split_output(command):
  """Runs the given command and splits its output on the null byte."""
  command_trace.log(command)
  result = subprocess.check_output(command, text=True, errors='replace')
  return [name for name in result.rstrip().split('\0') if name]

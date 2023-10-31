#!/usr/bin/env python

# Copyright 2020 Google LLC
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

"""Prints logs from test runs captured in Apple .xcresult bundles.

USAGE: xcresult_logs.py -workspace <path> -scheme <scheme> [other flags...]

xcresult_logs.py finds and displays the log output associated with an xcodebuild
invocation. Pass your entire xcodebuild command-line as arguments to this script
and it will find the output associated with the most recent invocation.
"""

import json
import logging
import os
import re
import shutil
import subprocess
import sys

from lib import command_trace

_logger = logging.getLogger('xcresult')


def main():
  args = sys.argv[1:]
  if not args:
    sys.stdout.write(__doc__)
    sys.exit(1)

  logging.basicConfig(format='%(message)s', level=logging.DEBUG)

  flags = parse_xcodebuild_flags(args)

  # If the result bundle path is specified in the xcodebuild flags, use that
  # otherwise, deduce
  xcresult_path = flags.get('-resultBundlePath')
  if xcresult_path is None:
    project = project_from_workspace_path(flags['-workspace'])
    scheme = flags['-scheme']
    xcresult_path = find_xcresult_path(project, scheme)

  log_id = find_log_id(xcresult_path)
  log = export_log(xcresult_path, log_id)

  # Avoid a potential UnicodeEncodeError raised by sys.stdout.write() by
  # doing a relaxed encoding ourselves.
  if hasattr(sys.stdout, 'buffer'):
    log_encoded = log.encode('utf8', errors='backslashreplace')
    sys.stdout.flush()
    sys.stdout.buffer.write(log_encoded)
  else:
    log_encoded = log.encode('ascii', errors='backslashreplace')
    log_decoded = log_encoded.decode('ascii', errors='strict')
    sys.stdout.write(log_decoded)


# Most flags on the xcodebuild command-line are uninteresting, so only pull
# flags with known behavior with names in this set.
INTERESTING_FLAGS = {
    '-resultBundlePath',
    '-scheme',
    '-workspace',
}


def parse_xcodebuild_flags(args):
  """Parses the xcodebuild command-line.

  Extracts flags like -workspace and -scheme that dictate the location of the
  logs.
  """
  result = {}
  key = None
  for arg in args:
    if arg.startswith('-'):
      if arg in INTERESTING_FLAGS:
        key = arg
    elif key is not None:
      result[key] = arg
      key = None

  return result


def project_from_workspace_path(path):
  """Extracts the project name from a workspace path.
  Args:
    path: The path to a .xcworkspace file

  Returns:
    The project name from the basename of the path. For example, if path were
    'Firestore/Example/Firestore.xcworkspace', returns 'Firestore'.
  """
  root, ext = os.path.splitext(os.path.basename(path))
  if ext == '.xcworkspace':
    _logger.debug('Using project %s from workspace %s', root, path)
    return root

  raise ValueError('%s is not a valid workspace path' % path)


def find_xcresult_path(project, scheme):
  """Finds an xcresult bundle for the given project and scheme.

  Args:
    project: The project name, like 'Firestore'
    scheme: The Xcode scheme that was tested

  Returns:
    The path to the newest xcresult bundle that matches.
  """
  project_path = find_project_path(project)
  bundle_dir = os.path.join(project_path, 'Logs/Test')
  prefix = re.compile('([^-]*)-' + re.escape(scheme) + '-')

  _logger.debug('Logging for xcresult bundles in %s', bundle_dir)
  xcresult = find_newest_matching_prefix(bundle_dir, prefix)
  if xcresult is None:
    raise LookupError(
        'Could not find xcresult bundle for %s in %s' % (scheme, bundle_dir))

  _logger.debug('Found xcresult: %s', xcresult)
  return xcresult


def find_project_path(project):
  """Finds the newest project output within Xcode's DerivedData.

  Args:
    project: A project name; the Foo in Foo.xcworkspace

  Returns:
    The path containing the newest project output.
  """
  path = os.path.expanduser('~/Library/Developer/Xcode/DerivedData')
  prefix = re.compile(re.escape(project) + '-')

  # DerivedData has directories like Firestore-csljdukzqbozahdjizcvrfiufrkb. Use
  # the most recent one if there are more than one such directory matching the
  # project name.
  result = find_newest_matching_prefix(path, prefix)
  if result is None:
    raise LookupError(
        'Could not find project derived data for %s in %s' % (project, path))

  _logger.debug('Using project derived data in %s', result)
  return result


def find_newest_matching_prefix(path, prefix):
  """Lists the given directory and returns the newest entry matching prefix.

  Args:
    path: A directory to list
    prefix: A regular expression that matches the filenames to consider

  Returns:
    The path to the newest entry in the directory whose basename starts with
    the prefix.
  """
  entries = os.listdir(path)
  result = None
  for entry in entries:
    if prefix.match(entry):
      fq_entry = os.path.join(path, entry)
      if result is None:
        result = fq_entry
      else:
        result_mtime = os.path.getmtime(result)
        entry_mtime = os.path.getmtime(fq_entry)
        if entry_mtime > result_mtime:
          result = fq_entry

  return result


def find_legacy_log_files(xcresult_path):
  """Finds the log files produced by Xcode 10 and below."""

  result = []

  for root, dirs, files in os.walk(xcresult_path, topdown=True):
    for file in files:
      if file.endswith('.txt'):
        file = os.path.join(root, file)
        result.append(file)

  # Sort the files by creation time.
  result.sort(key=lambda f: os.stat(f).st_ctime)
  return result


def cat_files(files, output):
  """Reads the contents of all the files and copies them to the output.

  Args:
    files: A list of filenames
    output: A file-like object in which all the data should be copied.
  """
  for file in files:
    with open(file, 'r') as fd:
      shutil.copyfileobj(fd, output)


def find_log_id(xcresult_path):
  """Finds the id of the last action's logs.

  Args:
    xcresult_path: The path to an xcresult bundle.

  Returns:
    The id of the log output, suitable for use with xcresulttool get --id.
  """
  parsed = xcresulttool_json('get', '--path', xcresult_path)
  actions = parsed['actions']['_values']
  action = actions[-1]

  result = action['actionResult']['logRef']['id']['_value']
  _logger.debug('Using log id %s', result)
  return result


def export_log(xcresult_path, log_id):
  """Exports the log data with the given id from the xcresult bundle.

  Args:
    xcresult_path: The path to an xcresult bundle.
    log_id: The id that names the log output (obtained by find_log_id)

  Returns:
    The logged output, as a string.
  """
  contents = xcresulttool_json('get', '--path', xcresult_path, '--id', log_id)

  result = []
  collect_log_output(contents, result)
  return ''.join(result)


def collect_log_output(activity_log, result):
  """Recursively collects emitted output from the activity log.

  Args:
    activity_log: Parsed JSON of an xcresult activity log.
    result: An array into which all log data should be appended.
  """
  output = activity_log.get('emittedOutput')
  if output:
    result.append(output['_value'])
  else:
    subsections = activity_log.get('subsections')
    if subsections:
      for subsection in subsections['_values']:
        collect_log_output(subsection, result)


def xcresulttool(*args):
  """Runs xcresulttool and returns its output as a string."""
  cmd = ['xcrun', 'xcresulttool']
  cmd.extend(args)

  command_trace.log(cmd)

  return subprocess.check_output(cmd)


def xcresulttool_json(*args):
  """Runs xcresulttool and its output as parsed JSON."""
  args = list(args) + ['--format', 'json']
  contents = xcresulttool(*args)
  return json.loads(contents)


if __name__ == '__main__':
  main()

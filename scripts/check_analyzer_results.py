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

"""Fails if an xcodebuild result bundle contains static analyzer warnings.

`xcodebuild analyze` exits with 0 even when the Clang static analyzer reports
issues, so CI needs this check to fail on them. It reads the structured
analyzer warnings from the result bundle with `xcresulttool`.

Only warnings in files under the repository root are reported. Warnings in
remote package dependencies are ignored; Xcode doesn't analyze those anyway.
Pass one or more path prefixes (relative to the repository root) to report only
warnings in those directories, for example the SDK's own sources.

Usage:
  check_analyzer_results.py RESULT_BUNDLE [PATH_PREFIX ...]
"""

import json
import os
import subprocess
import sys
import urllib.parse


def load_build_results(result_bundle):
  output = subprocess.check_output([
      'xcrun', 'xcresulttool', 'get', 'build-results', '--path',
      result_bundle
  ])
  return json.loads(output)


def parse_source_url(source_url):
  """Returns (path, line) from a result bundle source URL.

  Source URLs look like
  `file:///path/to/File.m#EndingColumnNumber=3&...&StartingLineNumber=41`.
  Line numbers in the fragment are zero-based.
  """
  parsed = urllib.parse.urlparse(source_url)
  path = urllib.parse.unquote(parsed.path)
  fragment = urllib.parse.parse_qs(parsed.fragment)
  line = None
  if 'StartingLineNumber' in fragment:
    line = int(fragment['StartingLineNumber'][0]) + 1
  return path, line


def main():
  if len(sys.argv) < 2:
    print(__doc__, file=sys.stderr)
    return 2

  result_bundle = sys.argv[1]
  prefixes = [p.rstrip('/') + '/' for p in sys.argv[2:]]
  repo_root = os.path.realpath(os.getcwd()) + '/'

  results = load_build_results(result_bundle)
  findings = []
  for warning in results.get('analyzerWarnings', []):
    path, line = parse_source_url(warning.get('sourceURL', ''))
    real_path = os.path.realpath(path) if path else ''
    if not real_path.startswith(repo_root):
      continue
    relative_path = real_path[len(repo_root):]
    if prefixes and not any(relative_path.startswith(p) for p in prefixes):
      continue
    findings.append((relative_path, line, warning.get('issueType', ''),
                     warning.get('message', '')))

  for relative_path, line, issue_type, message in sorted(set(findings)):
    location = 'file=%s' % relative_path
    if line:
      location += ',line=%d' % line
    # GitHub Actions annotation, also readable in a local terminal.
    print('::error %s,title=Static analyzer (%s)::%s' %
          (location, issue_type, message))

  scope = ', '.join(sys.argv[2:]) if prefixes else 'the repository'
  if findings:
    print('Found %d static analyzer warning(s) in %s.' %
          (len(set(findings)), scope))
    return 1
  print('No static analyzer warnings in %s.' % scope)
  return 0


if __name__ == '__main__':
  sys.exit(main())

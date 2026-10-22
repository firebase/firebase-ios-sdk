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

"""Prints the newest simulator runtime that supports a given device type.

USAGE: select_simulator_runtime.py --platform <names> --device-type <id>

Some simulator runtimes are device-specific (for example, a point release that
only ships with new hardware), so the newest runtime installed for a platform
cannot be assumed to support every device type. This script queries `simctl`
for the available runtimes and prints the identifier of the newest one whose
supported device types include the requested device type.

Example:

  select_simulator_runtime.py --platform 'visionOS|xrOS' \\
      --device-type com.apple.CoreSimulator.SimDeviceType.Apple-Vision-Pro-4K
"""

import argparse
import json
import re
import subprocess
import sys


def main():
  """Prints the selected runtime identifier and returns the exit status."""
  args = _parse_args()
  platforms = {platform.lower() for platform in args.platforms}

  try:
    available_runtimes = _list_available_runtimes()
  except subprocess.CalledProcessError as error:
    print(f'Error: {error}', file=sys.stderr)
    return 1
  except (OSError, ValueError) as error:  # Missing xcrun or malformed JSON.
    print(f'Error: Could not list simulator runtimes: {error}', file=sys.stderr)
    return 1

  runtimes = [
      runtime for runtime in available_runtimes
      if _platform_name(runtime) in platforms
  ]
  candidates = [
      runtime for runtime in runtimes
      if _supports_device_type(runtime, args.device_type)
  ]
  if not candidates:
    _report_no_match(args.platforms, args.device_type, runtimes)
    return 1

  newest = max(candidates, key=_version_key)
  print(newest['identifier'])
  return 0


def _parse_args():
  """Parses the command-line arguments."""
  parser = argparse.ArgumentParser(
      description=__doc__.splitlines()[0],
      epilog=('Exits with status 1 if no runtime matches or simctl fails, or '
              '2 on usage errors.'))
  parser.add_argument(
      '--platform',
      dest='platforms',
      metavar='NAMES',
      required=True,
      type=_platform_names,
      help=('Platform name, or `|`-separated alternatives (e.g. "iOS" or '
            '"visionOS|xrOS"). Matched case-insensitively.'))
  parser.add_argument(
      '--device-type',
      metavar='ID',
      required=True,
      help=('Simulator device type identifier (e.g. '
            '"com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro").'))
  return parser.parse_args()


def _platform_names(value):
  """Parses a `|`-separated list of platform names.

  Args:
    value: The raw `--platform` argument, such as "visionOS|xrOS".

  Returns:
    A list of platform names with surrounding whitespace removed.

  Raises:
    argparse.ArgumentTypeError: If `value` contains no platform names.
  """
  names = [name.strip() for name in value.split('|') if name.strip()]
  if not names:
    raise argparse.ArgumentTypeError('expected at least one platform name')
  return names


def _list_available_runtimes():
  """Returns the available simulator runtimes reported by `simctl`.

  Raises:
    subprocess.CalledProcessError: If `simctl` fails.
    OSError: If `xcrun` cannot be run.
    json.JSONDecodeError: If `simctl` prints malformed JSON.
  """
  output = subprocess.check_output(
      ['xcrun', 'simctl', 'list', '-j', 'runtimes', 'available'], text=True)
  return [
      runtime for runtime in json.loads(output).get('runtimes', [])
      if runtime.get('isAvailable') and 'identifier' in runtime
  ]


def _platform_name(runtime):
  """Returns the lowercase platform name of `runtime`, such as "ios"."""
  return runtime.get('platform', '').lower()


def _supports_device_type(runtime, device_type):
  """Returns whether `runtime` supports the device type `device_type`."""
  return any(
      supported.get('identifier') == device_type
      for supported in runtime.get('supportedDeviceTypes', []))


def _version_key(runtime):
  """Returns a sortable key for the version of `runtime`.

  Only the numeric components are used, so "18.3.1" sorts after "18.3" and a
  malformed version such as "27.0 beta" does not raise.
  """
  version = runtime.get('version', '')
  return tuple(int(part) for part in re.findall(r'\d+', version))


def _report_no_match(platforms, device_type, runtimes):
  """Prints an error describing why no runtime was selected.

  Args:
    platforms: The platform names that were searched.
    device_type: The requested simulator device type identifier.
    runtimes: The available runtimes for `platforms`.
  """
  platform_list = '|'.join(platforms)
  print(
      f'Error: No available {platform_list} runtime supports {device_type}.',
      file=sys.stderr)
  print(f'Available {platform_list} runtimes:', file=sys.stderr)
  if not runtimes:
    print('  (none)', file=sys.stderr)
  for runtime in sorted(runtimes, key=_version_key):
    name = runtime.get('name', '?')
    identifier = runtime['identifier']
    print(f'  {name} ({identifier})', file=sys.stderr)


if __name__ == '__main__':
  sys.exit(main())

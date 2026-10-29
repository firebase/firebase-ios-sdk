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

"""Prints the simulator device type and newest runtime that supports it.

USAGE: select_simulator_runtime.py --platform <names> --device-type <ids>

Some simulator runtimes are device-specific (for example, a point release that
only ships with new hardware), so the newest runtime installed for a platform
cannot be assumed to support every device type. Conversely, some platforms
change device types across OS generations (for example, visionOS 2 uses
`Apple-Vision-Pro` while visionOS 26+ uses `Apple-Vision-Pro-4K`).

This script queries `simctl` for the available runtimes, finds the newest one
whose supported device types include any of the requested device types
(preferring runtimes matching the active Xcode's simulator SDK major version
when available), and prints `<device_type> <runtime_identifier>`.

Example:

  prefix=com.apple.CoreSimulator.SimDeviceType
  select_simulator_runtime.py --platform 'visionOS|xrOS' \\
      --device-type "${prefix}.Apple-Vision-Pro-4K|${prefix}.Apple-Vision-Pro"
"""

import argparse
import json
import re
import subprocess
import sys

_SDK_BY_PLATFORM = {
    'ios': 'iphonesimulator',
    'tvos': 'appletvsimulator',
    'visionos': 'xrsimulator',
    'watchos': 'watchsimulator',
    'xros': 'xrsimulator',
}


def main(argv=None):
  """Prints `<device_type> <runtime_id>` and returns the exit status."""
  args = _parse_args(argv)
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
  candidates = []
  for runtime_index, runtime in enumerate(runtimes):
    device_index = _first_supported_device_index(runtime, args.device_types)
    if device_index is not None:
      candidates.append((runtime_index, device_index, runtime))

  if not candidates:
    _report_no_match(args.platforms, args.device_types, runtimes)
    return 1

  # Prefer runtimes matching the active Xcode's simulator SDK major version so
  # multi-Xcode hosts do not pick an incompatible newer major OS, while still
  # choosing the highest point release within that major version to align with
  # xcodebuild's implicit OS:latest destination resolution.
  sdk_major = _active_sdk_major(args.platforms)
  if sdk_major is not None:
    sdk_candidates = [
        item for item in candidates if _runtime_major(item[2]) == sdk_major
    ]
    if sdk_candidates:
      candidates = sdk_candidates

  # Prefer the highest OS version, then earlier device-type preference, then
  # later entries in simctl's ascending build-ordered runtime list.
  _, device_index, newest = max(
      candidates,
      key=lambda item: (_version_key(item[2]), -item[1], item[0]),
  )
  print(f'{args.device_types[device_index]} {newest["identifier"]}')
  return 0


def _parse_args(argv=None):
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
      type=_pipe_separated('platform name'),
      help=('Platform name, or `|`-separated alternatives (e.g. "iOS" or '
            '"visionOS|xrOS"). Matched case-insensitively.'))
  parser.add_argument(
      '--device-type',
      dest='device_types',
      metavar='IDS',
      required=True,
      type=_pipe_separated('device type'),
      help=('Simulator device type identifier, or `|`-separated fallbacks '
            'in preference order (e.g. '
            '"com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro").'))
  return parser.parse_args(argv)


def _pipe_separated(item_label):
  """Returns an `argparse` type parser for `|`-separated values."""

  def _parse(value):
    values = [item.strip() for item in value.split('|') if item.strip()]
    if not values:
      raise argparse.ArgumentTypeError(f'expected at least one {item_label}')
    return values

  return _parse


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


def _active_sdk_major(platforms):
  """Returns the active Xcode's simulator SDK major version, or `None`."""
  seen_sdks = set()
  for platform in platforms:
    sdk_name = _SDK_BY_PLATFORM.get(platform.lower())
    if sdk_name is None or sdk_name in seen_sdks:
      continue
    seen_sdks.add(sdk_name)
    try:
      version = subprocess.check_output(
          ['xcrun', '--sdk', sdk_name, '--show-sdk-version'],
          stderr=subprocess.DEVNULL,
          text=True,
      )
    except (subprocess.CalledProcessError, OSError):
      continue
    match = re.match(r'\s*(\d+)', version)
    if match:
      return int(match.group(1))
  return None


def _runtime_major(runtime):
  """Returns the major version integer of `runtime`, or `None`."""
  parts, _ = _version_key(runtime)
  return parts[0] if parts else None


def _platform_name(runtime):
  """Returns the lowercase platform name of `runtime`, such as "ios"."""
  return runtime.get('platform', '').lower()


def _first_supported_device_index(runtime, device_types):
  """Returns the first index in `device_types` supported by `runtime`."""
  supported = {
      entry.get('identifier')
      for entry in runtime.get('supportedDeviceTypes', [])
  }
  for index, device_type in enumerate(device_types):
    if device_type in supported:
      return index
  return None


def _version_key(runtime):
  """Returns a sortable key for the version of `runtime`.

  Leading dotted numeric components are compared numerically with trailing zeros
  normalized (so "18.3.1" > "18.3" and "27.0" == "27.0.0"). A release version
  sorts after a pre-release suffix with the same numeric prefix (so "27.0" >
  "27.0 beta 2", without treating "2" as a patch component).
  """
  version = runtime.get('version', '')
  match = re.match(r'\s*(\d+(?:\.\d+)*)(.*)', version)
  if not match:
    return ((), False)
  parts = [int(part) for part in match.group(1).split('.')]
  while len(parts) > 1 and parts[-1] == 0:
    parts.pop()
  is_release = not match.group(2).strip()
  return (tuple(parts), is_release)


def _report_no_match(platforms, device_types, runtimes):
  """Prints an error describing why no runtime was selected.

  Args:
    platforms: The platform names that were searched.
    device_types: The requested simulator device type identifiers.
    runtimes: The available runtimes for `platforms`.
  """
  platform_list = '|'.join(platforms)
  device_list = '|'.join(device_types)
  print(
      f'Error: No available {platform_list} runtime supports {device_list}.',
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

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

"""Unit tests for `select_simulator_runtime`."""

import contextlib
import io
import json
import subprocess
import unittest
from unittest import mock

import select_simulator_runtime

_DEV_PREFIX = 'com.apple.CoreSimulator.SimDeviceType'
_RUN_PREFIX = 'com.apple.CoreSimulator.SimRuntime'

_IPHONE_15_PRO = f'{_DEV_PREFIX}.iPhone-15-Pro'
_IPHONE_DUO = f'{_DEV_PREFIX}.iPhone-Duo'
_VISION_PRO = f'{_DEV_PREFIX}.Apple-Vision-Pro'
_VISION_PRO_4K = f'{_DEV_PREFIX}.Apple-Vision-Pro-4K'
_VISION_AIR = f'{_DEV_PREFIX}.Apple-Vision-Air'


def _runtime(
    identifier,
    platform='iOS',
    version='26.0',
    name=None,
    device_types=(),
    is_available=True,
):
  """Builds a `simctl`-shaped runtime dictionary for tests."""
  entry = {
      'isAvailable': is_available,
      'platform': platform,
      'version': version,
      'name': name or f'{platform} {version}',
      'supportedDeviceTypes': [{'identifier': dt} for dt in device_types],
  }
  if identifier is not None:
    entry['identifier'] = identifier
  return entry


def _run_main(argv, runtimes, sdk_version=None):
  """Runs `main(argv)` against mocked `simctl` and `xcrun --sdk` outputs."""
  payload = json.dumps({'runtimes': runtimes})

  def _fake_check_output(cmd, **_kwargs):
    if cmd[:2] == ['xcrun', 'simctl']:
      return payload
    if cmd[:2] == ['xcrun', '--sdk']:
      if sdk_version is None:
        raise subprocess.CalledProcessError(1, cmd)
      return f'{sdk_version}\n'
    raise AssertionError(f'Unexpected subprocess call: {cmd}')

  stdout = io.StringIO()
  stderr = io.StringIO()
  with mock.patch.object(
      subprocess, 'check_output', side_effect=_fake_check_output
  ) as check_output:
    with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
      status = select_simulator_runtime.main(argv)
  return status, stdout.getvalue(), stderr.getvalue(), check_output


class SelectSimulatorRuntimeTest(unittest.TestCase):
  """Tests runtime and device-type selection in `select_simulator_runtime`."""

  def test_skips_newer_device_specific_runtime(self):
    runtimes = [
        _runtime(
            f'{_RUN_PREFIX}.iOS-27-0',
            version='27.0',
            device_types=[_IPHONE_15_PRO],
        ),
        _runtime(
            f'{_RUN_PREFIX}.iOS-27-1',
            version='27.1',
            device_types=[_IPHONE_DUO],
        ),
    ]

    status, stdout, stderr, _ = _run_main(
        ['--platform', 'iOS', '--device-type', _IPHONE_15_PRO], runtimes
    )

    self.assertEqual(status, 0)
    self.assertEqual(stdout, f'{_IPHONE_15_PRO} {_RUN_PREFIX}.iOS-27-0\n')
    self.assertEqual(stderr, '')

  def test_ios_fallback_selects_newer_runtime_with_fallback_device(self):
    runtimes = [
        _runtime(
            f'{_RUN_PREFIX}.iOS-27-0',
            version='27.0',
            device_types=[_IPHONE_15_PRO],
        ),
        _runtime(
            f'{_RUN_PREFIX}.iOS-27-1',
            version='27.1',
            device_types=[_IPHONE_DUO],
        ),
    ]

    status, stdout, stderr, _ = _run_main(
        [
            '--platform',
            'iOS',
            '--device-type',
            f'{_IPHONE_15_PRO}|{_IPHONE_DUO}',
        ],
        runtimes,
        sdk_version='27.1',
    )

    self.assertEqual(status, 0)
    self.assertEqual(stdout, f'{_IPHONE_DUO} {_RUN_PREFIX}.iOS-27-1\n')
    self.assertEqual(stderr, '')

  def test_scopes_selection_to_active_xcode_sdk_major_version(self):
    runtimes = [
        _runtime(
            f'{_RUN_PREFIX}.iOS-18-4',
            version='18.4',
            device_types=[_IPHONE_15_PRO],
        ),
        _runtime(
            f'{_RUN_PREFIX}.iOS-18-5',
            version='18.5',
            device_types=[_IPHONE_15_PRO],
        ),
        _runtime(
            f'{_RUN_PREFIX}.iOS-26-2',
            version='26.2',
            device_types=[_IPHONE_15_PRO],
        ),
    ]

    status, stdout, _, check_output = _run_main(
        ['--platform', 'iOS', '--device-type', _IPHONE_15_PRO],
        runtimes,
        sdk_version='18.5',
    )

    self.assertEqual(status, 0)
    self.assertEqual(stdout, f'{_IPHONE_15_PRO} {_RUN_PREFIX}.iOS-18-5\n')
    check_output.assert_any_call(
        ['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'],
        stderr=subprocess.DEVNULL,
        text=True,
    )

  def test_scopes_visionos_to_xrsimulator_sdk_major_version(self):
    runtimes = [
        _runtime(
            f'{_RUN_PREFIX}.xrOS-2-5',
            platform='xrOS',
            version='2.5',
            name='visionOS 2.5',
            device_types=[_VISION_PRO],
        ),
        _runtime(
            f'{_RUN_PREFIX}.xrOS-26-2',
            platform='xrOS',
            version='26.2',
            name='visionOS 26.2',
            device_types=[_VISION_PRO_4K],
        ),
    ]

    status, stdout, _, check_output = _run_main(
        [
            '--platform',
            'visionOS|xrOS',
            '--device-type',
            f'{_VISION_PRO_4K}|{_VISION_PRO}',
        ],
        runtimes,
        sdk_version='2.5',
    )

    self.assertEqual(status, 0)
    self.assertEqual(stdout, f'{_VISION_PRO} {_RUN_PREFIX}.xrOS-2-5\n')
    check_output.assert_any_call(
        ['xcrun', '--sdk', 'xrsimulator', '--show-sdk-version'],
        stderr=subprocess.DEVNULL,
        text=True,
    )

  def test_selects_highest_point_release_within_active_sdk_major(self):
    runtimes = [
        _runtime(
            f'{_RUN_PREFIX}.iOS-26-4',
            version='26.4',
            device_types=[_IPHONE_15_PRO],
        ),
        _runtime(
            f'{_RUN_PREFIX}.iOS-26-5',
            version='26.5',
            device_types=[_IPHONE_15_PRO],
        ),
        _runtime(
            f'{_RUN_PREFIX}.iOS-27-1',
            version='27.1',
            device_types=[_IPHONE_DUO],
        ),
    ]

    status, stdout, _, _ = _run_main(
        [
            '--platform',
            'iOS',
            '--device-type',
            f'{_IPHONE_15_PRO}|{_IPHONE_DUO}',
        ],
        runtimes,
        sdk_version='26.4',
    )

    self.assertEqual(status, 0)
    self.assertEqual(stdout, f'{_IPHONE_15_PRO} {_RUN_PREFIX}.iOS-26-5\n')

  def test_falls_back_when_no_runtime_matches_active_sdk_major(self):
    runtimes = [
        _runtime(
            f'{_RUN_PREFIX}.iOS-26-5',
            version='26.5',
            device_types=[_IPHONE_15_PRO],
        ),
        _runtime(
            f'{_RUN_PREFIX}.iOS-27-1',
            version='27.1',
            device_types=[_IPHONE_DUO],
        ),
    ]

    for sdk_version in ('27.1', ''):
      status, stdout, _, _ = _run_main(
          ['--platform', 'iOS', '--device-type', _IPHONE_15_PRO],
          runtimes,
          sdk_version=sdk_version,
      )
      self.assertEqual(status, 0)
      self.assertEqual(stdout, f'{_IPHONE_15_PRO} {_RUN_PREFIX}.iOS-26-5\n')

  def test_compares_multi_part_and_multi_digit_versions_numerically(self):
    runtimes = [
        _runtime(
            f'{_RUN_PREFIX}.iOS-18-3',
            version='18.3',
            device_types=[_IPHONE_15_PRO],
        ),
        _runtime(
            f'{_RUN_PREFIX}.iOS-18-3-1',
            version='18.3.1',
            device_types=[_IPHONE_15_PRO],
        ),
        _runtime(
            f'{_RUN_PREFIX}.iOS-26-2',
            version='26.2',
            device_types=[_IPHONE_15_PRO],
        ),
        _runtime(
            f'{_RUN_PREFIX}.iOS-26-10',
            version='26.10',
            device_types=[_IPHONE_15_PRO],
        ),
    ]

    status, stdout, _, _ = _run_main(
        ['--platform', 'iOS', '--device-type', _IPHONE_15_PRO], runtimes
    )

    self.assertEqual(status, 0)
    self.assertEqual(stdout, f'{_IPHONE_15_PRO} {_RUN_PREFIX}.iOS-26-10\n')

  def test_prerelease_suffix_digits_do_not_outrank_release(self):
    runtimes = [
        _runtime(
            f'{_RUN_PREFIX}.iOS-27-0-release',
            version='27.0',
            device_types=[_IPHONE_15_PRO],
        ),
        _runtime(
            f'{_RUN_PREFIX}.iOS-27-0-beta2',
            version='27.0 beta 2',
            device_types=[_IPHONE_15_PRO],
        ),
    ]

    status, stdout, _, _ = _run_main(
        ['--platform', 'iOS', '--device-type', _IPHONE_15_PRO], runtimes
    )

    self.assertEqual(status, 0)
    self.assertEqual(
        stdout, f'{_IPHONE_15_PRO} {_RUN_PREFIX}.iOS-27-0-release\n'
    )

  def test_same_version_prefers_later_build_in_simctl_order(self):
    runtimes = [
        _runtime(
            f'{_RUN_PREFIX}.iOS-27-2-beta',
            version='27.2.0',
            device_types=[_IPHONE_15_PRO],
        ),
        _runtime(
            f'{_RUN_PREFIX}.iOS-27-2-gm',
            version='27.2',
            device_types=[_IPHONE_15_PRO],
        ),
    ]

    status, stdout, _, _ = _run_main(
        ['--platform', 'iOS', '--device-type', _IPHONE_15_PRO], runtimes
    )

    self.assertEqual(status, 0)
    self.assertEqual(stdout, f'{_IPHONE_15_PRO} {_RUN_PREFIX}.iOS-27-2-gm\n')

  def test_visionos_fallback_device_types_selects_newest_runtime(self):
    # Even if xrOS 2.5 appears after xrOS 26.2 in simctl output, version
    # comparison selects xrOS 26.2 with Apple-Vision-Pro-4K.
    runtimes = [
        _runtime(
            f'{_RUN_PREFIX}.xrOS-26-2',
            platform='xrOS',
            version='26.2',
            name='visionOS 26.2',
            device_types=[_VISION_PRO_4K],
        ),
        _runtime(
            f'{_RUN_PREFIX}.xrOS-2-5',
            platform='xrOS',
            version='2.5',
            name='visionOS 2.5',
            device_types=[_VISION_PRO],
        ),
    ]

    status, stdout, _, _ = _run_main(
        [
            '--platform',
            'visionOS|xrOS',
            '--device-type',
            f'{_VISION_PRO_4K}|{_VISION_PRO}',
        ],
        runtimes,
    )

    self.assertEqual(status, 0)
    self.assertEqual(stdout, f'{_VISION_PRO_4K} {_RUN_PREFIX}.xrOS-26-2\n')

  def test_visionos_falls_back_to_legacy_device_when_newer_incompatible(self):
    runtimes = [
        _runtime(
            f'{_RUN_PREFIX}.xrOS-2-5',
            platform='xrOS',
            version='2.5',
            name='visionOS 2.5',
            device_types=[_VISION_PRO],
        ),
        _runtime(
            f'{_RUN_PREFIX}.visionOS-27-1',
            platform='visionOS',
            version='27.1',
            name='visionOS 27.1',
            device_types=[_VISION_AIR],
        ),
    ]

    status, stdout, _, _ = _run_main(
        [
            '--platform',
            'visionOS|xrOS',
            '--device-type',
            f'{_VISION_PRO_4K}|{_VISION_PRO}',
        ],
        runtimes,
    )

    self.assertEqual(status, 0)
    self.assertEqual(stdout, f'{_VISION_PRO} {_RUN_PREFIX}.xrOS-2-5\n')

  def test_prefers_earlier_device_type_when_runtime_supports_multiple(self):
    runtimes = [
        _runtime(
            f'{_RUN_PREFIX}.visionOS-26-0',
            platform='visionOS',
            version='26.0',
            device_types=[_VISION_PRO, _VISION_PRO_4K],
        ),
    ]

    status, stdout, _, _ = _run_main(
        [
            '--platform',
            'visionOS|xrOS',
            '--device-type',
            f'{_VISION_PRO_4K}|{_VISION_PRO}',
        ],
        runtimes,
    )

    self.assertEqual(status, 0)
    self.assertEqual(stdout, f'{_VISION_PRO_4K} {_RUN_PREFIX}.visionOS-26-0\n')

  def test_ignores_unavailable_and_identifierless_runtimes(self):
    runtimes = [
        _runtime(
            f'{_RUN_PREFIX}.iOS-26-0',
            version='26.0',
            device_types=[_IPHONE_15_PRO],
        ),
        _runtime(
            f'{_RUN_PREFIX}.iOS-27-0',
            version='27.0',
            device_types=[_IPHONE_15_PRO],
            is_available=False,
        ),
        _runtime(
            None,
            version='28.0',
            device_types=[_IPHONE_15_PRO],
        ),
    ]

    status, stdout, _, _ = _run_main(
        ['--platform', 'ios', '--device-type', _IPHONE_15_PRO], runtimes
    )

    self.assertEqual(status, 0)
    self.assertEqual(stdout, f'{_IPHONE_15_PRO} {_RUN_PREFIX}.iOS-26-0\n')

  def test_reports_available_platform_runtimes_on_no_match(self):
    runtimes = [
        _runtime(
            f'{_RUN_PREFIX}.iOS-27-1',
            version='27.1',
            name='iOS 27.1',
            device_types=[_IPHONE_DUO],
        ),
        _runtime(
            f'{_RUN_PREFIX}.iOS-26-5',
            version='26.5',
            name='iOS 26.5',
            device_types=[_IPHONE_DUO],
        ),
    ]

    status, stdout, stderr, _ = _run_main(
        ['--platform', 'iOS', '--device-type', _IPHONE_15_PRO], runtimes
    )

    self.assertEqual(status, 1)
    self.assertEqual(stdout, '')
    self.assertIn(
        f'Error: No available iOS runtime supports {_IPHONE_15_PRO}.', stderr
    )
    self.assertIn(
        f'  iOS 26.5 ({_RUN_PREFIX}.iOS-26-5)\n'
        f'  iOS 27.1 ({_RUN_PREFIX}.iOS-27-1)\n',
        stderr,
    )

  def test_reports_none_when_platform_has_no_runtimes(self):
    status, stdout, stderr, _ = _run_main(
        ['--platform', 'watchOS', '--device-type', _IPHONE_15_PRO], []
    )

    self.assertEqual(status, 1)
    self.assertEqual(stdout, '')
    self.assertIn('  (none)\n', stderr)

  def test_handles_subprocess_and_json_errors(self):
    error_cases = [
        subprocess.CalledProcessError(1, ['xcrun', 'simctl']),
        FileNotFoundError('xcrun not found'),
    ]
    for side_effect in error_cases:
      with mock.patch.object(
          subprocess, 'check_output', side_effect=side_effect
      ):
        with contextlib.redirect_stderr(io.StringIO()) as stderr:
          status = select_simulator_runtime.main(
              ['--platform', 'iOS', '--device-type', _IPHONE_15_PRO]
          )
      self.assertEqual(status, 1)
      self.assertIn('Error:', stderr.getvalue())

    with mock.patch.object(
        subprocess, 'check_output', return_value='{bad json'
    ):
      with contextlib.redirect_stderr(io.StringIO()) as stderr:
        status = select_simulator_runtime.main(
            ['--platform', 'iOS', '--device-type', _IPHONE_15_PRO]
        )
    self.assertEqual(status, 1)
    self.assertIn('Could not list simulator runtimes', stderr.getvalue())

  def test_rejects_empty_pipe_separated_arguments(self):
    for bad_args in (
        ['--platform', ' | ', '--device-type', _IPHONE_15_PRO],
        ['--platform', 'iOS', '--device-type', '|'],
    ):
      with contextlib.redirect_stderr(io.StringIO()):
        with self.assertRaises(SystemExit) as ctx:
          select_simulator_runtime.main(bad_args)
      self.assertEqual(ctx.exception.code, 2)


if __name__ == '__main__':
  unittest.main()

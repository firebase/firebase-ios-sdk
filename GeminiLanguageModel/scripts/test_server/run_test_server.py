#!/usr/bin/env python3
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Runs google/test-server in record or replay mode for integration tests.

This script configures and launches google/test-server as a local reverse proxy
to record or replay HTTP interactions against the Gemini and Firebase APIs.
"""

from collections.abc import Sequence
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys


def find_test_server_binary() -> Path | None:
    """Locates the test-server executable on the system.

    Returns:
        Path to the test-server binary if found, or None.
    """
    env_bin = os.environ.get('TEST_SERVER_BIN')
    if env_bin:
        path = Path(env_bin)
        if path.is_file() and os.access(path, os.X_OK):
            return path

    which_bin = shutil.which('test-server')
    if which_bin:
        return Path(which_bin)

    home_bin = Path.home() / 'go' / 'bin' / 'test-server'
    if home_bin.is_file() and os.access(home_bin, os.X_OK):
        return home_bin

    if shutil.which('go'):
        try:
            raw_gopath = subprocess.check_output(
                ['go', 'env', 'GOPATH'],
                text=True,
                timeout=5,
                stderr=subprocess.DEVNULL,
            ).strip()
            for path_entry in raw_gopath.split(os.pathsep):
                if path_entry:
                    go_bin = Path(path_entry) / 'bin' / 'test-server'
                    if go_bin.is_file() and os.access(go_bin, os.X_OK):
                        return go_bin
        except (subprocess.SubprocessError, OSError):
            pass

    return None


def extract_secrets_from_plist(plist_path: Path) -> dict[str, str]:
    """Extracts project ID and API key from a GoogleService-Info.plist file.

    Args:
        plist_path: Path to the GoogleService-Info.plist file.

    Returns:
        Dictionary mapping keys ('PROJECT_ID', 'API_KEY') to their values.
    """
    secrets: dict[str, str] = {}
    if not plist_path.is_file():
        print(
            f'Warning: Plist file not found at {plist_path}',
            file=sys.stderr,
        )
        return secrets

    try:
        with open(plist_path, 'rb') as f:
            plist = plistlib.load(f)
        if isinstance(plist, dict):
            for key in ('PROJECT_ID', 'API_KEY'):
                val = plist.get(key)
                if val:
                    secrets[key] = str(val).strip()
        else:
            print(
                f'Warning: Plist at {plist_path} is not a dictionary.',
                file=sys.stderr,
            )
    except (plistlib.InvalidFileException, OSError, ValueError) as e:
        print(
            f'Warning: Failed to parse plist at {plist_path}: {e}',
            file=sys.stderr,
        )

    return secrets


def resolve_test_server_secrets() -> list[str]:
    """Gathers secrets to be redacted by test-server.

    Checks FIREBASE_PLIST_PATH first. If not provided, inspects standard
    environment variables.

    Returns:
        List of secret strings to be passed to TEST_SERVER_SECRETS.
    """
    existing = os.environ.get('TEST_SERVER_SECRETS')
    if existing:
        return [s.strip() for s in existing.split(',') if s.strip()]

    secrets: list[str] = []

    plist_env = os.environ.get('FIREBASE_PLIST_PATH')
    if plist_env:
        plist_secrets = extract_secrets_from_plist(Path(plist_env))
        for key in ('PROJECT_ID', 'API_KEY'):
            val = plist_secrets.get(key)
            if val and val not in secrets:
                secrets.append(val)
    else:
        secret_keys = [
            'FIREBASE_PROJECT_ID',
            'GOOGLE_CLOUD_PROJECT',
            'GCLOUD_PROJECT',
            'FIREBASE_API_KEY',
        ]
        for key in secret_keys:
            val = os.environ.get(key)
            if val and val not in secrets:
                secrets.append(val)

    for key in ('GEMINI_API_KEY', 'GOOGLE_API_KEY'):
        val = os.environ.get(key)
        if val and val not in secrets:
            secrets.append(val)

    return secrets


def main(argv: Sequence[str] | None = None) -> None:
    """Configures and runs google/test-server.

    Args:
        argv: Command-line arguments. Defaults to sys.argv[1:] if None.
    """
    if argv is None:
        argv = sys.argv[1:]

    if len(argv) > 1:
        print(f'Usage: {sys.argv[0]} [record|replay]', file=sys.stderr)
        sys.exit(1)

    mode = argv[0] if argv else 'replay'
    if mode not in ('record', 'replay'):
        print(f'Usage: {sys.argv[0]} [record|replay]', file=sys.stderr)
        sys.exit(1)

    script_dir = Path(__file__).resolve().parent
    config_file = Path(
        os.environ.get(
            'TEST_SERVER_CONFIG', str(script_dir / 'test_server_config.yaml')
        )
    )
    if not config_file.is_file():
        print(
            f'Error: Configuration file not found at: {config_file}',
            file=sys.stderr,
        )
        sys.exit(1)

    recording_dir = Path(
        os.environ.get(
            'TEST_SERVER_RECORDING_DIR', str(script_dir / 'recordings')
        )
    )

    test_server_bin = find_test_server_binary()
    if not test_server_bin:
        print(
            'Error: test-server executable not found.\n\n'
            'To install google/test-server, run:\n'
            '  go install github.com/google/test-server@latest\n\n'
            'Or download a pre-built binary from:\n'
            '  https://github.com/google/test-server/releases\n\n'
            'Or set TEST_SERVER_BIN to the path of your test-server binary.',
            file=sys.stderr,
        )
        sys.exit(1)

    recording_dir.mkdir(parents=True, exist_ok=True)

    secrets = resolve_test_server_secrets()
    if secrets:
        os.environ['TEST_SERVER_SECRETS'] = ','.join(secrets)

    print(f'Starting test-server in {mode} mode...')
    print(f'  Binary:        {test_server_bin}')
    print(f'  Configuration: {config_file}')
    print(f'  Recordings:    {recording_dir}')

    sys.stdout.flush()
    sys.stderr.flush()

    cmd = [
        str(test_server_bin),
        mode,
        '--config',
        str(config_file),
        '--recording-dir',
        str(recording_dir),
    ]

    try:
        os.execv(str(test_server_bin), cmd)
    except OSError as e:
        print(
            f'Error: Failed to execute {test_server_bin}: {e}',
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == '__main__':
    main()

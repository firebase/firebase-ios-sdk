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

"""Writes rendered Swift sources to disk, formats them, and prunes stale files."""

from __future__ import annotations

from collections.abc import Iterable
import os
import shutil
import subprocess


def remove_case_conflicts(file_path: str) -> None:
    """Removes files differing from file_path only by case.

    Avoids stale files surviving a rename on case-insensitive filesystems
    such as APFS.

    Args:
        file_path: The path about to be written.
    """
    dir_name = os.path.dirname(file_path)
    base_name = os.path.basename(file_path)
    if os.path.exists(dir_name):
        for existing in os.listdir(dir_name):
            if existing.lower() == base_name.lower() and existing != base_name:
                os.remove(os.path.join(dir_name, existing))


def write_files(
    rendered: Iterable[tuple[str, str]],
    output_dir: str,
    verbose: bool = False,
) -> list[str]:
    """Writes rendered (filename, source) pairs into output_dir.

    Args:
        rendered: Iterable of (filename, source) tuples.
        output_dir: Target directory path for Swift source files.
        verbose: Whether to print verbose progress.

    Returns:
        List of paths to newly written files.
    """
    os.makedirs(output_dir, exist_ok=True)
    written_files: list[str] = []
    for filename, source in rendered:
        file_path = os.path.join(output_dir, filename)
        remove_case_conflicts(file_path)
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(source)
        written_files.append(file_path)
        if verbose:
            print(f"Generated type: {filename}")
    return written_files


def run_swift_format(paths: list[str], verbose: bool = False) -> None:
    """Formats files in place with swift-format, if it is on PATH.

    Args:
        paths: Swift files to format.
        verbose: Whether to print verbose progress.
    """
    swift_format_bin = shutil.which("swift-format")
    if not swift_format_bin or not paths:
        return
    try:
        res = subprocess.run(
            [swift_format_bin, "format", "-i"] + paths,
            capture_output=True,
            text=True,
            check=False,
        )
        if res.returncode == 0:
            if verbose:
                print(f"Formatted {len(paths)} files with swift-format.")
        elif verbose:
            print(f"swift-format notice: {res.stderr.strip()}")
    except Exception as e:
        if verbose:
            print(f"Warning: swift-format could not be executed: {e}")


def prune_stale_files(
    output_dir: str,
    written_files: list[str],
    preserved_files: Iterable[str],
    verbose: bool = False,
) -> None:
    """Removes previously generated .swift files that were not just written.

    Args:
        output_dir: Directory containing generated Swift sources.
        written_files: Paths written by the current run.
        preserved_files: File names that must never be removed.
        verbose: Whether to print verbose progress.
    """
    preserved = set(preserved_files)
    written = set(written_files)
    written_files_lower = {w.lower() for w in written_files}
    for existing in os.listdir(output_dir):
        if existing.endswith(".swift") and existing not in preserved:
            full_path = os.path.join(output_dir, existing)
            if (
                full_path not in written
                and full_path.lower() not in written_files_lower
            ):
                os.remove(full_path)
                if verbose:
                    print(f"Removed old generated file: {existing}")

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

import contextlib
import io
import os
import subprocess
import tempfile
import unittest
from unittest import mock

from swift_typegen import output


class TestOutput(unittest.TestCase):

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.out = self.temp_dir.name

    def tearDown(self):
        self.temp_dir.cleanup()

    def _touch(self, name: str) -> str:
        path = os.path.join(self.out, name)
        with open(path, "w", encoding="utf-8") as f:
            f.write("// old\n")
        return path

    def test_write_files_writes_sources(self):
        written = output.write_files(
            [("A.swift", "struct A {}\n"), ("B.swift", "struct B {}\n")],
            self.out,
        )
        self.assertEqual(
            written,
            [
                os.path.join(self.out, "A.swift"),
                os.path.join(self.out, "B.swift"),
            ],
        )
        with open(written[0], encoding="utf-8") as f:
            self.assertEqual(f.read(), "struct A {}\n")

    def test_write_files_creates_output_dir(self):
        nested = os.path.join(self.out, "nested", "dir")
        output.write_files([("A.swift", "")], nested)
        self.assertTrue(os.path.exists(os.path.join(nested, "A.swift")))

    def test_write_files_removes_case_conflicting_files(self):
        self._touch("UrlContext.swift")
        output.write_files(
            [("URLContext.swift", "struct URLContext {}\n")], self.out
        )
        self.assertIn("URLContext.swift", os.listdir(self.out))
        self.assertNotIn("UrlContext.swift", os.listdir(self.out))

    def test_prune_stale_files(self):
        kept = self._touch("Kept.swift")
        self._touch("Stale.swift")
        self._touch("Preserved.swift")
        self._touch("README.md")

        output.prune_stale_files(
            self.out, [kept], preserved_files={"Preserved.swift"}
        )

        self.assertEqual(
            sorted(os.listdir(self.out)),
            ["Kept.swift", "Preserved.swift", "README.md"],
        )


def _which(available: dict[str, str]):
    """Returns a shutil.which replacement resolving only `available`."""
    return lambda name: available.get(name)


class TestSwiftFormat(unittest.TestCase):

    @mock.patch("swift_typegen.output.subprocess.run")
    @mock.patch("swift_typegen.output.shutil.which")
    def test_find_swift_format_prefers_path(self, which, run):
        which.side_effect = _which({"swift-format": "/bin/swift-format"})
        self.assertEqual(output.find_swift_format(), "/bin/swift-format")
        run.assert_not_called()

    @mock.patch("swift_typegen.output.os.path.exists", return_value=True)
    @mock.patch("swift_typegen.output.subprocess.run")
    @mock.patch("swift_typegen.output.shutil.which")
    def test_find_swift_format_falls_back_to_xcrun(self, which, run, _):
        which.side_effect = _which({"xcrun": "/usr/bin/xcrun"})
        run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="/Xcode/swift-format\n", stderr=""
        )
        self.assertEqual(output.find_swift_format(), "/Xcode/swift-format")
        run.assert_called_once()
        self.assertEqual(
            run.call_args.args[0], ["/usr/bin/xcrun", "--find", "swift-format"]
        )

    @mock.patch("swift_typegen.output.shutil.which", return_value=None)
    def test_run_swift_format_warns_when_missing(self, _):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            output.run_swift_format(["A.swift"])
        self.assertIn("swift-format not found", out.getvalue())

    @mock.patch("swift_typegen.output.subprocess.run")
    @mock.patch(
        "swift_typegen.output.find_swift_format",
        return_value="/bin/swift-format",
    )
    def test_run_swift_format_warns_on_failure(self, _, run):
        run.return_value = subprocess.CompletedProcess(
            args=[], returncode=1, stdout="", stderr="bad input"
        )
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            output.run_swift_format(["A.swift"])
        self.assertIn("exited with status 1: bad input", out.getvalue())

    @mock.patch("swift_typegen.output.find_swift_format")
    def test_run_swift_format_skips_empty_paths(self, find):
        output.run_swift_format([])
        find.assert_not_called()

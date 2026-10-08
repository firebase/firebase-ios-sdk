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

"""Unit tests for swift_typegen.output."""

import os
import tempfile
import unittest

from swift_typegen.output import prune_stale_files, write_files


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
        written = write_files(
            [("A.swift", "struct A {}\n"), ("B.swift", "struct B {}\n")],
            self.out,
        )
        self.assertEqual(
            written,
            [os.path.join(self.out, "A.swift"), os.path.join(self.out, "B.swift")],
        )
        with open(written[0], encoding="utf-8") as f:
            self.assertEqual(f.read(), "struct A {}\n")

    def test_write_files_creates_output_dir(self):
        nested = os.path.join(self.out, "nested", "dir")
        write_files([("A.swift", "")], nested)
        self.assertTrue(os.path.exists(os.path.join(nested, "A.swift")))

    def test_write_files_removes_case_conflicting_files(self):
        self._touch("UrlContext.swift")
        write_files([("URLContext.swift", "struct URLContext {}\n")], self.out)
        self.assertIn("URLContext.swift", os.listdir(self.out))
        self.assertNotIn("UrlContext.swift", os.listdir(self.out))

    def test_prune_stale_files(self):
        kept = self._touch("Kept.swift")
        self._touch("Stale.swift")
        self._touch("Preserved.swift")
        self._touch("README.md")

        prune_stale_files(self.out, [kept], preserved_files={"Preserved.swift"})

        self.assertEqual(
            sorted(os.listdir(self.out)),
            ["Kept.swift", "Preserved.swift", "README.md"],
        )


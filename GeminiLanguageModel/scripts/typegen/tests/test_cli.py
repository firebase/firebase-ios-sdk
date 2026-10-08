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

"""Unit tests for swift_typegen.cli."""

import os
import unittest

from swift_typegen.cli import PACKAGE_ROOT, TYPEGEN_DIR, parse_args


class TestCli(unittest.TestCase):

    def test_typegen_dir_contains_expected_directories(self):
        for name in ("swift_typegen", "templates", "discovery_documents"):
            self.assertTrue(
                os.path.isdir(os.path.join(TYPEGEN_DIR, name)),
                f"{name}/ not found under TYPEGEN_DIR={TYPEGEN_DIR}",
            )

    def test_default_paths_exist(self):
        options = parse_args([])
        self.assertEqual(
            options.openapi_spec,
            os.path.join(
                TYPEGEN_DIR,
                "discovery_documents",
                "firebasevertexai-openapi.yaml",
            ),
        )
        self.assertTrue(os.path.isfile(options.overrides_file))
        self.assertTrue(
            os.path.isfile(
                os.path.join(options.templates_dir, "struct.swift.jinja")
            )
        )
        self.assertIsNone(options.strip_prefixes)
        self.assertEqual(
            options.output_dir,
            os.path.join(
                PACKAGE_ROOT,
                "Sources",
                "GeminiAPIDataModels",
                "GenerateContent",
            ),
        )
        self.assertTrue(os.path.isdir(options.output_dir))

    def test_flags_map_to_options(self):
        options = parse_args(
            [
                "--roots",
                "A",
                "B",
                "--strip-prefix",
                "--namespace",
                "NS",
                "--access-level",
                "public",
                "--doc-wrap-width",
                "80",
                "--verbose",
            ]
        )
        self.assertEqual(options.roots, ("A", "B"))
        self.assertEqual(options.strip_prefixes, ())
        self.assertEqual(options.namespace, "NS")
        self.assertEqual(options.access_level, "public")
        self.assertEqual(options.doc_wrap_width, 80)
        self.assertTrue(options.verbose)

    def test_strip_prefix_values_map_to_tuple(self):
        options = parse_args(["--strip-prefix", "B", "A"])
        self.assertEqual(options.strip_prefixes, ("B", "A"))

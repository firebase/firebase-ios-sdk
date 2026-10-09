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

"""Unit tests for swift_typegen.config."""

import os
import tempfile
import unittest

from swift_typegen.config import (
    DEVELOPER_TAG,
    ENTERPRISE_TAG,
    Backend,
    GeneratorConfig,
    provenance_key,
)


class TestGeneratorConfig(unittest.TestCase):

    def test_provenance_key_builds_extension_key(self):
        self.assertEqual(
            provenance_key(DEVELOPER_TAG, "description"),
            "x-gl-developer-description",
        )
        self.assertEqual(
            provenance_key(ENTERPRISE_TAG, "original-name"),
            "x-ai-enterprise-original-name",
        )

    def test_generator_config_defaults(self):
        config = GeneratorConfig()
        self.assertEqual(config.type_overrides, {})
        self.assertEqual(config.excluded_schemas, set())
        self.assertEqual(config.excluded_properties, {})

    def test_from_file_missing_returns_defaults(self):
        config = GeneratorConfig.from_file("/nonexistent/overrides.yaml")
        self.assertEqual(config, GeneratorConfig())

    def test_from_file_parses_generator_config(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "overrides.yaml")
            with open(path, "w", encoding="utf-8") as f:
                f.write(
                    "generatorConfig:\n"
                    "  excludedSchemas: [A, B]\n"
                    "  manualOverrideSchemas: [C]\n"
                    "  renameMappings: {Old: New}\n"
                    "  typeOverrides: {Struct: JSONObject}\n"
                    "  backends:\n"
                    "    - {prefix: DeveloperPrefix, tag: gl-developer}\n"
                    "    - {prefix: EnterprisePrefix, tag: ai-enterprise}\n"
                    "  preservedFiles: [Manual.swift]\n"
                )
            config = GeneratorConfig.from_file(path)
        self.assertEqual(config.excluded_schemas, {"A", "B"})
        self.assertEqual(config.manual_override_schemas, {"C"})
        self.assertEqual(config.rename_mappings, {"Old": "New"})
        self.assertEqual(config.type_overrides, {"Struct": "JSONObject"})
        self.assertEqual(
            config.backends,
            [
                Backend("DeveloperPrefix", "gl-developer"),
                Backend("EnterprisePrefix", "ai-enterprise"),
            ],
        )
        self.assertEqual(config.preserved_files, {"Manual.swift"})

    def test_backend_rejects_unknown_tag(self):
        with self.assertRaises(ValueError):
            Backend(prefix="Prefix", tag="xx")

    def test_backend_rejects_empty_prefix(self):
        with self.assertRaises(ValueError):
            Backend(prefix="", tag="gl-developer")

    def test_rejects_duplicate_backend_prefixes(self):
        with self.assertRaisesRegex(ValueError, "prefix"):
            GeneratorConfig(
                backends=[
                    Backend("Same", "gl-developer"),
                    Backend("Same", "ai-enterprise"),
                ]
            )

    def test_rejects_duplicate_backend_tags(self):
        with self.assertRaisesRegex(ValueError, "tag"):
            GeneratorConfig(
                backends=[
                    Backend("One", "gl-developer"),
                    Backend("Two", "gl-developer"),
                ]
            )

    def test_from_file_rejects_malformed_backend_entries(self):
        for entry in (
            "{prefix: OnlyPrefix}",
            "{tag: gl-developer}",
            "JustAString",
        ):
            with self.subTest(entry=entry):
                with tempfile.TemporaryDirectory() as tmp:
                    path = os.path.join(tmp, "overrides.yaml")
                    with open(path, "w", encoding="utf-8") as f:
                        f.write(f"generatorConfig:\n  backends:\n    - {entry}\n")
                    with self.assertRaisesRegex(ValueError, "backends entry"):
                        GeneratorConfig.from_file(path)

    def test_backend_for_prefix(self):
        config = GeneratorConfig(
            backends=[Backend("DeveloperPrefix", "gl-developer")]
        )
        self.assertEqual(
            config.backend_for_prefix("DeveloperPrefix").tag, "gl-developer"
        )
        with self.assertRaises(ValueError):
            config.backend_for_prefix("Unknown")

    def test_repo_overrides_file_configures_backends(self):
        typegen_dir = os.path.dirname(
            os.path.dirname(os.path.abspath(__file__))
        )
        config = GeneratorConfig.from_file(
            os.path.join(
                typegen_dir,
                "discovery_documents",
                "firebasevertexai-overrides.yaml",
            )
        )
        self.assertEqual(
            [b.tag for b in config.backends], ["gl-developer", "ai-enterprise"]
        )
        self.assertIn("ResponseFormatConfig.swift", config.preserved_files)

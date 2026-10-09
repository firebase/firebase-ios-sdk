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
import dataclasses
import io
import os
import tempfile
import unittest
from unittest import mock

import yaml

from swift_typegen import config as config_lib
from swift_typegen import models
from swift_typegen import pipeline

DEVELOPER = config_lib.Backend(
    "GoogleAiGenerativelanguageV1beta", "gl-developer"
)
ENTERPRISE = config_lib.Backend("GoogleCloudAiplatformV1beta1", "ai-enterprise")

TYPEGEN_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATES_DIR = os.path.join(TYPEGEN_DIR, "templates")


class TestLoadConfig(unittest.TestCase):

    def test_missing_overrides_file_raises(self):
        with self.assertRaises(FileNotFoundError):
            pipeline.load_config("/nonexistent/overrides.yaml")

    def test_missing_spec_file_raises_with_upgrade_spec_hint(self):
        with self.assertRaisesRegex(FileNotFoundError, "upgrade_spec.py"):
            pipeline.load_spec("/nonexistent/openapi.yaml")

    def test_spec_without_schemas_raises(self):
        for contents in ("", "# only a comment\n", "components: {}\n"):
            with self.subTest(contents=contents):
                with tempfile.TemporaryDirectory() as tmp:
                    path = os.path.join(tmp, "openapi.yaml")
                    with open(path, "w", encoding="utf-8") as f:
                        f.write(contents)
                    with self.assertRaisesRegex(
                        ValueError, "No components.schemas"
                    ):
                        pipeline.load_spec(path)

    def test_loads_existing_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "overrides.yaml")
            with open(path, "w", encoding="utf-8") as f:
                f.write("generatorConfig:\n  excludedSchemas: [A]\n")
            with contextlib.redirect_stdout(io.StringIO()):
                config = pipeline.load_config(path)
        self.assertEqual(config.excluded_schemas, {"A"})


class TestSelectBackends(unittest.TestCase):

    def setUp(self):
        self.config = config_lib.GeneratorConfig(
            backends=[DEVELOPER, ENTERPRISE]
        )

    def test_none_selects_all_configured_backends(self):
        self.assertEqual(
            pipeline.select_backends(None, self.config), [DEVELOPER, ENTERPRISE]
        )

    def test_none_without_configured_backends_raises(self):
        with self.assertRaisesRegex(ValueError, "--strip-prefix"):
            pipeline.select_backends(None, config_lib.GeneratorConfig())

    def test_empty_list_disables_stripping(self):
        self.assertEqual(pipeline.select_backends([], self.config), [])
        self.assertEqual(
            pipeline.select_backends([], config_lib.GeneratorConfig()), []
        )

    def test_merge_order_is_developer_api_first(self):
        self.assertEqual(
            pipeline.select_backends(
                [ENTERPRISE.prefix, DEVELOPER.prefix], self.config
            ),
            [DEVELOPER, ENTERPRISE],
        )
        reversed_config = config_lib.GeneratorConfig(
            backends=[ENTERPRISE, DEVELOPER]
        )
        self.assertEqual(
            pipeline.select_backends(None, reversed_config),
            [DEVELOPER, ENTERPRISE],
        )

    def test_duplicate_prefixes_are_selected_once(self):
        self.assertEqual(
            pipeline.select_backends(
                [ENTERPRISE.prefix, ENTERPRISE.prefix], self.config
            ),
            [ENTERPRISE],
        )

    def test_unknown_prefix_raises(self):
        with self.assertRaises(ValueError):
            pipeline.select_backends(["Unknown"], self.config)


class TestPreprocessBackend(unittest.TestCase):

    def test_strips_prefix_and_resolves_from_roots(self):
        base_schemas = {
            f"{ENTERPRISE.prefix}Root": {
                "type": "object",
                "properties": {
                    "child": {
                        "$ref": (
                            f"#/components/schemas/{ENTERPRISE.prefix}Child"
                        )
                    }
                },
            },
            f"{ENTERPRISE.prefix}Child": {"type": "object", "properties": {}},
            f"{ENTERPRISE.prefix}Unreachable": {
                "type": "object",
                "properties": {},
            },
        }
        with contextlib.redirect_stdout(io.StringIO()):
            resolved = pipeline.preprocess_backend(
                base_schemas, ENTERPRISE, ["Root"], config_lib.GeneratorConfig()
            )
        self.assertEqual(set(resolved), {"Root", "Child"})
        self.assertEqual(
            resolved["Root"]["x-ai-enterprise-original-name"],
            f"{ENTERPRISE.prefix}Root",
        )
        # The input is deep-copied, not mutated.
        self.assertNotIn(
            "x-ai-enterprise-original-name",
            base_schemas[f"{ENTERPRISE.prefix}Root"],
        )

    def test_no_backend_leaves_names_unchanged(self):
        base_schemas = {"Root": {"type": "object", "properties": {}}}
        with contextlib.redirect_stdout(io.StringIO()):
            resolved = pipeline.preprocess_backend(
                base_schemas, None, ["Root"], config_lib.GeneratorConfig()
            )
        self.assertEqual(list(resolved), ["Root"])
        self.assertNotIn("x-gl-developer-original-name", resolved["Root"])


@mock.patch("swift_typegen.output.run_swift_format")
class TestRunPipeline(unittest.TestCase):
    """End-to-end tests of run() and write_types() against a temp directory."""

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        tmp = self.temp_dir.name
        self.out = os.path.join(tmp, "out")
        os.makedirs(self.out)
        for name in ("Manual.swift", "Stale.swift"):
            with open(os.path.join(self.out, name), "w", encoding="utf-8") as f:
                f.write("// existing\n")

        root = {
            "type": "object",
            "description": "Root.",
            "properties": {"name": {"type": "string", "description": "Name."}},
        }
        enterprise_root = copy_with_property(
            root, "extra", {"type": "integer", "description": "Extra."}
        )
        self.spec = os.path.join(tmp, "spec.yaml")
        write_yaml(
            self.spec,
            {
                "components": {
                    "schemas": {
                        f"{DEVELOPER.prefix}Root": root,
                        f"{ENTERPRISE.prefix}Root": enterprise_root,
                    }
                }
            },
        )
        self.overrides = os.path.join(tmp, "overrides.yaml")
        write_yaml(
            self.overrides,
            {
                "generatorConfig": {
                    "backends": [
                        {"prefix": DEVELOPER.prefix, "tag": "gl-developer"},
                        {"prefix": ENTERPRISE.prefix, "tag": "ai-enterprise"},
                    ],
                    "preservedFiles": ["Manual.swift"],
                }
            },
        )
        self.options = pipeline.PipelineOptions(
            openapi_spec=self.spec,
            templates_dir=TEMPLATES_DIR,
            output_dir=self.out,
            roots=("Root",),
            access_level="package",
            strip_prefixes=None,
            namespace="",
            shared_models_target="",
            overrides_file=self.overrides,
            doc_wrap_width=100,
        )

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_run_merges_backends_and_prunes_stale_files(self, mock_format):
        with contextlib.redirect_stdout(io.StringIO()):
            pipeline.run(self.options)
        self.assertEqual(
            set(os.listdir(self.out)), {"Root.swift", "Manual.swift"}
        )
        with open(os.path.join(self.out, "Root.swift"), encoding="utf-8") as f:
            source = f.read()
        self.assertIn("name", source)
        self.assertIn("extra", source)
        self.assertIn("not supported in the Gemini Developer API", source)
        mock_format.assert_called_once()

    def test_run_without_configured_backends_leaves_output_untouched(
        self, mock_format
    ):
        write_yaml(self.overrides, {"generatorConfig": {"preservedFiles": []}})
        before = sorted(os.listdir(self.out))
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(ValueError):
                pipeline.run(self.options)
        self.assertEqual(sorted(os.listdir(self.out)), before)
        mock_format.assert_not_called()

    def test_run_with_missing_overrides_leaves_output_untouched(
        self, mock_format
    ):
        options = dataclasses.replace(
            self.options, overrides_file=self.overrides + ".missing"
        )
        before = sorted(os.listdir(self.out))
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(FileNotFoundError):
                pipeline.run(options)
        self.assertEqual(sorted(os.listdir(self.out)), before)
        mock_format.assert_not_called()

    def test_write_types_preserves_configured_and_namespace_files(
        self, mock_format
    ):
        with open(
            os.path.join(self.out, "NS.swift"), "w", encoding="utf-8"
        ) as f:
            f.write("// namespace\n")
        options = dataclasses.replace(self.options, namespace="NS")
        swift_types = [
            models.SwiftType(name="Thing", namespace="NS", kind="struct")
        ]

        written = pipeline.write_types(swift_types, options, ["Manual.swift"])

        self.assertEqual(len(written), 1)
        self.assertEqual(
            set(os.listdir(self.out)),
            {os.path.basename(written[0]), "Manual.swift", "NS.swift"},
        )
        mock_format.assert_called_once_with(written, verbose=False)


def copy_with_property(schema, name, prop):
    """Returns a deep copy of schema with an extra property added."""
    result = yaml.safe_load(yaml.safe_dump(schema))
    result["properties"][name] = prop
    return result


def write_yaml(path, data):
    with open(path, "w", encoding="utf-8") as f:
        yaml.safe_dump(data, f)

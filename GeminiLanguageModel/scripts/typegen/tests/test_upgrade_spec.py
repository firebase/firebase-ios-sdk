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

import contextlib
import io
import json
import os
import tempfile
import unittest
from unittest import mock

import yaml

import upgrade_spec

PREFIXES = (
    "GoogleAiGenerativelanguageV1beta",
    "GoogleCloudAiplatformV1beta1",
)


class TestUpgradeSpec(unittest.TestCase):
    """Test suite covering Discovery transformations in upgrade_spec."""

    def test_normalize_refs(self):
        data = {
            "prop": {"$ref": "SomeSchema"},
            "nested": {
                "arr": [{"$ref": "ItemSchema"}],
                "already_normalized": {"$ref": "#/components/schemas/Existing"},
            },
        }
        upgrade_spec.normalize_refs(data)
        self.assertEqual(
            data["prop"]["$ref"], "#/components/schemas/SomeSchema"
        )
        self.assertEqual(
            data["nested"]["arr"][0]["$ref"],
            "#/components/schemas/ItemSchema",
        )
        self.assertEqual(
            data["nested"]["already_normalized"]["$ref"],
            "#/components/schemas/Existing",
        )

    def test_infer_required_properties(self):
        schemas = {
            "SampleSchema": {
                "type": "object",
                "properties": {
                    "reqField": {
                        "type": "string",
                        "description": "Required. Must provide this value.",
                    },
                    "optField": {
                        "type": "string",
                        "description": "Optional. Extra information.",
                    },
                    "reqColonField": {
                        "type": "string",
                        "description": "Required: Follow format.",
                    },
                },
            }
        }
        upgrade_spec.infer_required_properties(schemas)
        self.assertEqual(
            schemas["SampleSchema"]["required"],
            ["reqField", "reqColonField"],
        )

    def test_extract_standalone_enums(self):
        schemas = {
            "GoogleAiGenerativelanguageV1betaSafetyRating": {
                "type": "object",
                "properties": {
                    "category": {
                        "type": "string",
                        "enum": [
                            "HARM_CATEGORY_UNSPECIFIED",
                            "HARM_CATEGORY_HATE_SPEECH",
                        ],
                        "description": "Safety category.",
                    }
                },
            },
            "GoogleAiGenerativelanguageV1betaGenerationConfig": {
                "type": "object",
                "properties": {
                    "responseModalities": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "enum": ["MODALITY_UNSPECIFIED", "TEXT", "IMAGE"],
                        },
                        "description": "Response modalities.",
                    }
                },
            },
        }
        upgrade_spec.extract_standalone_enums(schemas, prefixes=PREFIXES)

        # Verify extracted top-level schemas
        self.assertIn("GoogleAiGenerativelanguageV1betaHarmCategory", schemas)
        self.assertIn("GoogleAiGenerativelanguageV1betaModality", schemas)

        # Verify properties replaced with refs
        category_prop = schemas["GoogleAiGenerativelanguageV1betaSafetyRating"][
            "properties"
        ]["category"]
        self.assertEqual(
            category_prop["$ref"],
            "#/components/schemas/GoogleAiGenerativelanguageV1betaHarmCategory",
        )

        modalities_prop = schemas[
            "GoogleAiGenerativelanguageV1betaGenerationConfig"
        ]["properties"]["responseModalities"]
        self.assertEqual(
            modalities_prop["items"]["$ref"],
            "#/components/schemas/GoogleAiGenerativelanguageV1betaModality",
        )

    def test_extract_standalone_enums_prefers_superset_cases(self):
        schemas = {
            "GoogleAiGenerativelanguageV1betaGenerationConfig": {
                "type": "object",
                "properties": {
                    "responseModalities": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "enum": [
                                "MODALITY_UNSPECIFIED",
                                "TEXT",
                                "IMAGE",
                                "AUDIO",
                            ],
                            "enumDescriptions": [
                                "Unspecified.",
                                "Text.",
                                "Image.",
                                "Audio.",
                            ],
                        },
                    }
                },
            },
            "GoogleAiGenerativelanguageV1betaModalityTokenCount": {
                "type": "object",
                "properties": {
                    "modality": {
                        "type": "string",
                        "enum": [
                            "MODALITY_UNSPECIFIED",
                            "TEXT",
                            "IMAGE",
                            "VIDEO",
                            "AUDIO",
                            "DOCUMENT",
                        ],
                        "enumDescriptions": [
                            "Unspecified.",
                            "Text.",
                            "Image.",
                            "Video.",
                            "Audio.",
                            "Document.",
                        ],
                    }
                },
            },
        }
        upgrade_spec.extract_standalone_enums(schemas, prefixes=PREFIXES)
        modality = schemas["GoogleAiGenerativelanguageV1betaModality"]
        self.assertEqual(
            modality["enum"],
            [
                "MODALITY_UNSPECIFIED",
                "TEXT",
                "IMAGE",
                "VIDEO",
                "AUDIO",
                "DOCUMENT",
            ],
        )
        self.assertEqual(
            modality["enumDescriptions"],
            [
                "Unspecified.",
                "Text.",
                "Image.",
                "Video.",
                "Audio.",
                "Document.",
            ],
        )

    def test_extract_standalone_enums_unions_non_superset_cases(self):
        def harm_prop(cases, deprecated):
            return {
                "type": "string",
                "enum": cases,
                "enumDescriptions": [f"{c}." for c in cases],
                "enumDeprecated": deprecated,
            }

        schemas = {
            "GoogleAiGenerativelanguageV1betaSafetyRating": {
                "type": "object",
                "properties": {
                    "category": harm_prop(
                        [
                            "HARM_CATEGORY_A",
                            "HARM_CATEGORY_B",
                            "HARM_CATEGORY_C",
                        ],
                        [False, True, False],
                    )
                },
            },
            "GoogleAiGenerativelanguageV1betaSafetySetting": {
                "type": "object",
                "properties": {
                    "category": harm_prop(
                        [
                            "HARM_CATEGORY_A",
                            "HARM_CATEGORY_B",
                            "HARM_CATEGORY_D",
                        ],
                        [False, False, False],
                    )
                },
            },
        }
        upgrade_spec.extract_standalone_enums(schemas, prefixes=PREFIXES)
        harm = schemas["GoogleAiGenerativelanguageV1betaHarmCategory"]
        # Equal-length, non-identical case lists are unioned rather than
        # dropping the second list's extra case.
        self.assertEqual(
            harm["enum"],
            [
                "HARM_CATEGORY_A",
                "HARM_CATEGORY_B",
                "HARM_CATEGORY_C",
                "HARM_CATEGORY_D",
            ],
        )
        self.assertEqual(
            harm["enumDescriptions"],
            [
                "HARM_CATEGORY_A.",
                "HARM_CATEGORY_B.",
                "HARM_CATEGORY_C.",
                "HARM_CATEGORY_D.",
            ],
        )
        # B is only deprecated in one of the two definitions.
        self.assertEqual(harm["enumDeprecated"], [False, False, False, False])

    def test_extract_standalone_enums_model_stage(self):
        schemas = {
            "GoogleAiGenerativelanguageV1betaModelStatus": {
                "type": "object",
                "properties": {
                    "modelStage": {
                        "type": "string",
                        "description": "The stage of the underlying model.",
                        "enum": [
                            "MODEL_STAGE_UNSPECIFIED",
                            "PREVIEW",
                            "STABLE",
                        ],
                    }
                },
            }
        }
        upgrade_spec.extract_standalone_enums(schemas, prefixes=PREFIXES)
        self.assertEqual(
            schemas["GoogleAiGenerativelanguageV1betaModelStage"]["enum"],
            ["MODEL_STAGE_UNSPECIFIED", "PREVIEW", "STABLE"],
        )
        self.assertEqual(
            schemas["GoogleAiGenerativelanguageV1betaModelStatus"][
                "properties"
            ]["modelStage"],
            {
                "$ref": (
                    "#/components/schemas/"
                    "GoogleAiGenerativelanguageV1betaModelStage"
                ),
                "description": "The stage of the underlying model.",
            },
        )

    def test_extract_standalone_enums_skips_non_enum_name_collision(self):
        schemas = {
            "GoogleAiGenerativelanguageV1betaModality": {
                "type": "object",
                "properties": {},
            },
            "GoogleAiGenerativelanguageV1betaPart": {
                "type": "object",
                "properties": {
                    "modality": {
                        "type": "string",
                        "enum": ["MODALITY_UNSPECIFIED", "TEXT"],
                    }
                },
            },
        }
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            upgrade_spec.extract_standalone_enums(schemas, prefixes=PREFIXES)
        self.assertIn("already used by a non-enum schema", out.getvalue())
        self.assertEqual(
            schemas["GoogleAiGenerativelanguageV1betaPart"]["properties"][
                "modality"
            ]["enum"],
            ["MODALITY_UNSPECIFIED", "TEXT"],
        )

    def test_extract_standalone_enums_prefixes_tool_type(self):
        schemas = {
            "GoogleAiGenerativelanguageV1betaToolCall": {
                "type": "object",
                "properties": {
                    "toolType": {
                        "type": "string",
                        "enum": ["TOOL_TYPE_UNSPECIFIED", "GOOGLE_SEARCH"],
                    }
                },
            },
        }
        upgrade_spec.extract_standalone_enums(schemas, prefixes=PREFIXES)
        self.assertIn("GoogleAiGenerativelanguageV1betaToolType", schemas)
        self.assertNotIn("ToolType", schemas)

    def test_extract_standalone_enums_uses_given_prefixes(self):
        schemas = {
            "VendorXSafetyRating": {
                "type": "object",
                "properties": {
                    "category": {
                        "type": "string",
                        "enum": ["HARM_CATEGORY_UNSPECIFIED"],
                    }
                },
            },
        }
        upgrade_spec.extract_standalone_enums(schemas, prefixes=["VendorX"])
        self.assertIn("VendorXHarmCategory", schemas)

    def test_upgrade_nullables_string_type(self):
        data = {"type": "string", "nullable": True}
        upgrade_spec.upgrade_nullables(data)
        self.assertEqual(data["type"], ["string", "null"])
        self.assertNotIn("nullable", data)

    def test_upgrade_nullables_list_type(self):
        data = {"type": ["integer"], "nullable": True}
        upgrade_spec.upgrade_nullables(data)
        self.assertEqual(data["type"], ["integer", "null"])
        self.assertNotIn("nullable", data)

    def test_upgrade_nullables_ref(self):
        data = {"$ref": "#/components/schemas/MyType", "nullable": True}
        upgrade_spec.upgrade_nullables(data)
        self.assertNotIn("nullable", data)
        self.assertNotIn("$ref", data)
        self.assertEqual(
            data["oneOf"],
            [{"$ref": "#/components/schemas/MyType"}, {"type": "null"}],
        )

    def test_simplify_all_of(self):
        data = {
            "allOf": [{"$ref": "#/components/schemas/MyType"}],
            "description": "Sibling description",
        }
        upgrade_spec.simplify_all_of(data)
        self.assertNotIn("allOf", data)
        self.assertEqual(data["$ref"], "#/components/schemas/MyType")
        self.assertEqual(data["description"], "Sibling description")

    def test_deep_merge(self):
        source = {
            "schemas": {
                "MySchema": {
                    "required": ["name"],
                    "properties": {"name": {"type": "string"}},
                }
            }
        }
        destination = {
            "schemas": {
                "MySchema": {
                    "required": ["oldField"],
                    "properties": {"oldField": {"type": "integer"}},
                }
            }
        }
        upgrade_spec.deep_merge(source, destination)
        self.assertEqual(
            destination["schemas"]["MySchema"]["required"], ["name"]
        )
        self.assertIn("name", destination["schemas"]["MySchema"]["properties"])
        self.assertIn(
            "oldField", destination["schemas"]["MySchema"]["properties"]
        )

    def test_deep_merge_replaces_non_dict_destination_values(self):
        source = {"items": {"$ref": "#/components/schemas/Part"}}
        for existing in (None, "string", 1):
            with self.subTest(existing=existing):
                destination = {"items": existing}
                upgrade_spec.deep_merge(source, destination)
                self.assertEqual(
                    destination,
                    {"items": {"$ref": "#/components/schemas/Part"}},
                )

    def test_deep_merge_removes_type_and_items_on_ref(self):
        source = {"$ref": "#/components/schemas/OverriddenRef"}
        destination = {
            "type": "array",
            "items": {"type": "string"},
            "description": "Original array",
        }
        upgrade_spec.deep_merge(source, destination)
        self.assertEqual(
            destination["$ref"], "#/components/schemas/OverriddenRef"
        )
        self.assertNotIn("type", destination)
        self.assertNotIn("items", destination)
        self.assertEqual(destination["description"], "Original array")

    @mock.patch("urllib.request.urlopen")
    def test_main_auto_fetches_when_input_file_missing(self, mock_urlopen):
        fake_discovery = {
            "title": "Test API",
            "version": "v1beta",
            "schemas": {
                "Sample": {
                    "type": "object",
                    "properties": {"name": {"type": "string"}},
                }
            },
        }
        resp = mock.MagicMock()
        resp.read.return_value = json.dumps(fake_discovery).encode("utf-8")
        mock_urlopen.return_value.__enter__.return_value = resp

        with tempfile.TemporaryDirectory() as tmp:
            input_file = os.path.join(tmp, "discovery.json")
            output_file = os.path.join(tmp, "openapi.yaml")
            overrides_file = os.path.join(tmp, "overrides.yaml")
            with open(overrides_file, "w", encoding="utf-8") as f:
                yaml.safe_dump({"schemas": {}}, f)

            with contextlib.redirect_stdout(io.StringIO()):
                upgrade_spec.main(
                    [
                        "--input-file",
                        input_file,
                        "--output-file",
                        output_file,
                        "--overrides-file",
                        overrides_file,
                    ]
                )

            mock_urlopen.assert_called_once()
            self.assertTrue(os.path.isfile(input_file))
            self.assertTrue(os.path.isfile(output_file))

    @mock.patch("urllib.request.urlopen")
    def test_main_uses_cached_input_file_without_fetch_flag(self, mock_urlopen):
        with tempfile.TemporaryDirectory() as tmp:
            input_file = os.path.join(tmp, "discovery.json")
            output_file = os.path.join(tmp, "openapi.yaml")
            overrides_file = os.path.join(tmp, "overrides.yaml")
            with open(input_file, "w", encoding="utf-8") as f:
                json.dump({"schemas": {}}, f)
            with open(overrides_file, "w", encoding="utf-8") as f:
                yaml.safe_dump({"schemas": {}}, f)

            with contextlib.redirect_stdout(io.StringIO()):
                upgrade_spec.main(
                    [
                        "--input-file",
                        input_file,
                        "--output-file",
                        output_file,
                        "--overrides-file",
                        overrides_file,
                    ]
                )

            mock_urlopen.assert_not_called()
            self.assertTrue(os.path.isfile(output_file))


if __name__ == "__main__":
    unittest.main()

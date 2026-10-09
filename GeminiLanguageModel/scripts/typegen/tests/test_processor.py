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

from __future__ import annotations

from typing import Any
import unittest

from swift_typegen import config as config_lib
from swift_typegen import models
from swift_typegen import processor


def process(
    resolved: dict[str, Any],
    namespace: str = "",
    config: config_lib.GeneratorConfig | None = None,
) -> list[models.SwiftType]:
    """Processes schemas with an empty (or given) configuration."""
    return processor.SchemaProcessor(
        config or config_lib.GeneratorConfig()
    ).process(resolved, namespace)


class TestSchemaProcessor(unittest.TestCase):

    def test_schema_processor_isolated_context(self):
        config = config_lib.GeneratorConfig(
            excluded_properties={"Candidate": {"groundingMetadata"}},
            excluded_schemas={"ExcludedType"},
        )
        schemas = {
            "Candidate": {
                "type": "object",
                "properties": {
                    "groundingMetadata": {"type": "string"},
                    "includedProp": {"type": "string"},
                    "badRef": {
                        "$ref": "#/components/schemas/ExcludedType"
                    },
                },
            }
        }
        swift_types = process(schemas, config=config)
        self.assertEqual(len(swift_types), 1)
        prop_names = [p.swift_name for p in swift_types[0].properties]
        self.assertEqual(prop_names, ["includedProp"])

    def test_strip_enum_prefix(self):
        cases = [
            "MEDIA_RESOLUTION_LOW",
            "MEDIA_RESOLUTION_MEDIUM",
            "MEDIA_RESOLUTION_HIGH",
        ]
        prefix, filtered = processor.strip_enum_prefix(cases)
        self.assertEqual(prefix, "MEDIA_RESOLUTION_")
        self.assertEqual(filtered, cases)

        cases = ["low", "medium", "high"]
        prefix, filtered = processor.strip_enum_prefix(cases)
        self.assertEqual(prefix, "")
        self.assertEqual(filtered, cases)

    def test_strip_enum_prefix_ignores_lowercase_sentinels(self):
        prefix, filtered = processor.strip_enum_prefix(
            ["unknown", "mode_fast", "mode_slow"]
        )
        self.assertEqual(prefix, "mode_")
        self.assertEqual(filtered, ["mode_fast", "mode_slow"])

    def test_is_sentinel_case(self):
        for value in (
            "UNSPECIFIED",
            "unknown",
            "MODE_UNSPECIFIED",
            "x_unknown",
        ):
            with self.subTest(value=value):
                self.assertTrue(processor.is_sentinel_case(value))
        for value in ("UNSPECIFIED_MODE", "KNOWN", "FAST"):
            with self.subTest(value=value):
                self.assertFalse(processor.is_sentinel_case(value))

    def test_dotted_namespace_nesting(self):
        schema_data = {
            "type": "object",
            "properties": {"level": {"type": "string"}},
        }
        resolved = {"Part.MediaResolution": schema_data}
        swift_types = process(resolved, "GeminiDataModels")
        self.assertEqual(len(swift_types), 1)
        st = swift_types[0]
        self.assertEqual(st.name, "MediaResolution")
        self.assertEqual(st.namespace, "GeminiDataModels.Part")
        self.assertEqual(st.kind, "struct")

    def test_firebase_flat_namespace_nesting(self):
        schema_data = {
            "type": "object",
            "properties": {"level": {"type": "string"}},
        }
        resolved = {
            "Candidate": {
                "type": "object",
                "properties": {"index": {"type": "integer"}},
            },
            "Part.MediaResolution": schema_data,
        }
        swift_types = process(resolved, "")
        self.assertEqual(len(swift_types), 2)
        top_level = next(t for t in swift_types if t.name == "Candidate")
        self.assertEqual(top_level.namespace, "")

        nested = next(t for t in swift_types if t.name == "MediaResolution")
        self.assertEqual(nested.namespace, "Part")

    def test_auto_exclusion_of_properties(self):
        config = config_lib.GeneratorConfig(
            excluded_schemas={"DynamicRetrievalConfig"}
        )
        schema_data = {
            "type": "object",
            "properties": {
                "dynamicRetrievalConfig": {
                    "$ref": "#/components/schemas/DynamicRetrievalConfig"
                },
                "otherProp": {"type": "string"},
            },
        }
        resolved = {"GoogleSearchRetrieval": schema_data}
        swift_types = process(resolved, "GeminiDataModels", config=config)
        self.assertEqual(len(swift_types), 1)
        st = swift_types[0]
        self.assertEqual(len(st.properties), 1)
        self.assertEqual(st.properties[0].swift_name, "otherProp")

    def test_standalone_top_level_enum_generation(self):
        schema_data = {
            "type": "string",
            "enum": ["unspecified", "standard", "flex"],
            "enumDescriptions": ["Default", "Standard", "Flexible"],
        }
        resolved = {"ServiceTier": schema_data}
        swift_types = process(resolved, "GeminiDataModels")
        self.assertEqual(len(swift_types), 1)
        st = swift_types[0]
        self.assertEqual(st.name, "ServiceTier")
        self.assertEqual(st.kind, "enum")
        self.assertEqual(len(st.cases), 2)
        self.assertEqual(st.cases[0].swift_name, "standard")
        self.assertEqual(st.cases[0].description, "Standard")

    def test_nullable_types_parsing(self):
        schema_data = {
            "type": "object",
            "properties": {"foo": {"type": ["string", "null"]}},
        }
        resolved = {"Parent": schema_data}
        swift_types = process(resolved, "GeminiDataModels")
        self.assertEqual(len(swift_types), 1)
        st = swift_types[0]
        self.assertEqual(len(st.properties), 1)
        prop = st.properties[0]
        self.assertEqual(prop.swift_type, "String")
        self.assertFalse(prop.is_required)

    def test_properties_sorted_alphabetically_in_generated_struct(self):
        schema_data = {
            "type": "object",
            "properties": {
                "zebra": {"type": "string"},
                "apple": {"type": "string"},
                "mango": {"type": "string"},
            },
        }
        resolved = {"Fruits": schema_data}
        swift_types = process(resolved, "GeminiDataModels")
        prop_names = [p.swift_name for p in swift_types[0].properties]
        self.assertEqual(prop_names, ["apple", "mango", "zebra"])

    def test_byte_format_mapping(self):
        prop_data = {"type": "string", "format": "byte"}
        self.assertEqual(processor.get_primitive_type(prop_data), "Data")

    def test_other_string_formats_map_to_string(self):
        for fmt in ("google-datetime", "date-time", "google-duration", None):
            with self.subTest(fmt=fmt):
                prop_data = {"type": "string", "format": fmt}
                self.assertEqual(
                    processor.get_primitive_type(prop_data), "String"
                )

    def test_property_type_override_replaces_primitive_mapping(self):
        config = config_lib.GeneratorConfig(
            property_type_overrides={"Part.thoughtSignature": "String"}
        )
        byte_prop = {"type": "string", "format": "byte"}
        resolved = {
            "Part": {
                "type": "object",
                "properties": {
                    "data": byte_prop,
                    "thoughtSignature": byte_prop,
                },
            },
            "Other": {
                "type": "object",
                "properties": {"thoughtSignature": byte_prop},
            },
        }
        swift_types = {t.name: t for t in process(resolved, config=config)}
        part_types = {p.swift_name: p.swift_type for p in swift_types["Part"].properties}
        self.assertEqual(part_types, {"data": "Data", "thoughtSignature": "String"})
        self.assertEqual(swift_types["Other"].properties[0].swift_type, "Data")

    def test_property_enum_becomes_nested_enum(self):
        resolved = {
            "SafetySetting": {
                "type": "object",
                "properties": {
                    "threshold": {
                        "type": "string",
                        "enum": [
                            "HARM_BLOCK_THRESHOLD_UNSPECIFIED",
                            "BLOCK_LOW_AND_ABOVE",
                            "BLOCK_NONE",
                        ],
                        "enumDescriptions": [
                            "Unspecified.",
                            "Optional. Block low and above.",
                            "Block none.",
                        ],
                        "enumDeprecated": [False, False, True],
                    }
                },
            }
        }
        swift_types = process(resolved)
        enum_type = next(t for t in swift_types if t.kind == "enum")
        self.assertEqual(enum_type.name, "Threshold")
        self.assertEqual(enum_type.namespace, "SafetySetting")
        # The shared "BLOCK_" prefix (ignoring the UNSPECIFIED sentinel) is
        # stripped from case names.
        self.assertEqual(
            [(c.swift_name, c.raw_value) for c in enum_type.cases],
            [("lowAndAbove", "BLOCK_LOW_AND_ABOVE"), ("none", "BLOCK_NONE")],
        )
        self.assertEqual(enum_type.cases[0].description, "Block low and above.")
        self.assertEqual(
            [c.is_deprecated for c in enum_type.cases], [False, True]
        )
        struct_type = next(t for t in swift_types if t.kind == "struct")
        self.assertEqual(struct_type.properties[0].swift_type, "Threshold")

    def test_single_value_enum_becomes_constant_without_nested_enum(self):
        resolved = {
            "Schema": {
                "type": "object",
                "properties": {
                    "kind": {"type": "string", "enum": ["OBJECT"]},
                },
            }
        }
        swift_types = process(resolved)
        self.assertEqual([t.kind for t in swift_types], ["struct"])
        prop = swift_types[0].properties[0]
        self.assertTrue(prop.is_const)
        self.assertEqual(prop.swift_type, "String")
        self.assertEqual(prop.const_value, '"OBJECT"')

    def test_const_property_maps_value_type(self):
        resolved = {
            "Flags": {
                "type": "object",
                "properties": {
                    "enabled": {"type": "boolean", "const": True},
                    "version": {"type": "integer", "const": 2},
                },
            }
        }
        props = {
            p.swift_name: (p.swift_type, p.const_value)
            for p in process(resolved)[0].properties
        }
        self.assertEqual(
            props, {"enabled": ("Bool", "true"), "version": ("Int", "2")}
        )

    def test_merged_enum_cases_document_backend_availability(self):
        resolved = {
            "HarmCategory": {
                "type": "string",
                "enum": [
                    "HARM_CATEGORY_UNSPECIFIED",
                    "HARM_CATEGORY_HATE_SPEECH",
                    "HARM_CATEGORY_DEROGATORY",
                    "HARM_CATEGORY_IMAGE_HATE",
                ],
                "enumDescriptions": ["Unused.", "Hate.", "Derogatory.", ""],
                "x-gl-developer-enum": [
                    "HARM_CATEGORY_UNSPECIFIED",
                    "HARM_CATEGORY_HATE_SPEECH",
                    "HARM_CATEGORY_DEROGATORY",
                ],
                "x-ai-enterprise-enum": [
                    "HARM_CATEGORY_UNSPECIFIED",
                    "HARM_CATEGORY_HATE_SPEECH",
                    "HARM_CATEGORY_IMAGE_HATE",
                ],
            }
        }
        (enum_type,) = process(resolved)
        descriptions = {c.swift_name: c.description for c in enum_type.cases}
        self.assertEqual(descriptions["hateSpeech"], "Hate.")
        self.assertEqual(
            descriptions["derogatory"],
            "Derogatory.\n\n> Important: This case is not supported in the"
            " Gemini Enterprise Agent Platform.",
        )
        self.assertEqual(
            descriptions["imageHate"],
            "> Important: This case is not supported in the Gemini Developer"
            " API.",
        )

    def test_single_backend_enum_cases_have_no_availability_callouts(self):
        resolved = {
            "ServiceTier": {
                "type": "string",
                "enum": ["STANDARD", "FLEX"],
                "enumDescriptions": ["Standard.", "Flex."],
                "x-gl-developer-enum": ["STANDARD", "FLEX"],
            }
        }
        (enum_type,) = process(resolved)
        self.assertEqual(
            [c.description for c in enum_type.cases], ["Standard.", "Flex."]
        )

    def test_reference_to_deprecated_schema_marks_property_deprecated(self):
        resolved = {
            "Holder": {
                "type": "object",
                "properties": {
                    "single": {"$ref": "#/components/schemas/Old"},
                    "many": {
                        "type": "array",
                        "items": {"$ref": "#/components/schemas/Old"},
                    },
                    "current": {"$ref": "#/components/schemas/New"},
                },
            },
            "Old": {"type": "object", "properties": {}, "deprecated": True},
            "New": {"type": "object", "properties": {}},
        }
        holder = next(t for t in process(resolved) if t.name == "Holder")
        deprecated = {p.swift_name: p.is_deprecated for p in holder.properties}
        self.assertEqual(
            deprecated, {"current": False, "many": True, "single": True}
        )

    def test_excluded_properties(self):
        config = config_lib.GeneratorConfig(
            excluded_properties={"GenerationConfig": {"_responseJsonSchema"}}
        )
        schema_data = {
            "type": "object",
            "properties": {
                "_responseJsonSchema": {"description": "internal detail"},
                "responseJsonSchema": {"description": "actual schema"},
            },
        }
        resolved = {"GenerationConfig": schema_data}
        swift_types = process(resolved, "", config=config)
        self.assertEqual(len(swift_types), 1)
        prop_names = [p.swift_name for p in swift_types[0].properties]
        self.assertEqual(prop_names, ["responseJSONSchema"])


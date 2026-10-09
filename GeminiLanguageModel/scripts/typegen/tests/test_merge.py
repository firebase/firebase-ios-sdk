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

"""Unit tests for swift_typegen.merge."""

import contextlib
import io
import unittest

from swift_typegen.config import Backend
from swift_typegen.merge import (
    merge_properties,
    merge_schemas,
    rename_schemas_and_refs,
    strip_prefix_from_schemas,
)


class TestMerge(unittest.TestCase):

    def test_schema_merging_order_preservation(self):
        schema1 = {
            "type": "object",
            "properties": {"a": {"type": "string"}, "c": {"type": "string"}},
        }
        schema2 = {
            "type": "object",
            "properties": {"b": {"type": "string"}, "a": {"type": "string"}},
        }
        merged = merge_schemas("Merged", schema1, schema2, divergences={})
        self.assertEqual(list(merged["properties"]), ["a", "b", "c"])

    def test_merge_properties_applies_divergence_resolution(self):
        prop1 = {"type": "object", "description": "One."}
        prop2 = {"type": "array", "description": "Two."}
        divergences = {"Parent": {"field": {"type": "string"}}}
        with contextlib.redirect_stdout(io.StringIO()):
            merged = merge_properties(
                "Parent", "field", prop1, prop2, divergences=divergences
            )
        self.assertEqual(merged["type"], "string")
        self.assertEqual(merged["description"], "One.\n\nVariant:\nTwo.")

    def test_merge_properties_promotes_numeric_types(self):
        with contextlib.redirect_stdout(io.StringIO()):
            merged = merge_properties(
                "Parent",
                "count",
                {"type": "integer", "format": "int32"},
                {"type": "number", "format": "double"},
                divergences={},
            )
        self.assertEqual(merged["type"], "number")
        self.assertNotIn("format", merged)

    def test_strip_prefix_from_schemas(self):
        prefix = "GoogleAiGenerativelanguageV1beta"
        schemas = {
            f"{prefix}Candidate": {
                "type": "object",
                "description": "A candidate.",
                "properties": {
                    "content": {
                        "$ref": f"#/components/schemas/{prefix}Content",
                        "description": "The content.",
                    }
                },
            },
        }
        stripped = strip_prefix_from_schemas(
            schemas, Backend(prefix, "gl-developer"), divergences={}
        )
        self.assertEqual(list(stripped), ["Candidate"])
        candidate = stripped["Candidate"]
        self.assertEqual(
            candidate["properties"]["content"]["$ref"],
            "#/components/schemas/Content",
        )
        self.assertEqual(
            candidate["x-gl-developer-original-name"], f"{prefix}Candidate"
        )
        self.assertEqual(
            candidate["x-gl-developer-description"], "A candidate."
        )
        self.assertEqual(
            candidate["properties"]["content"]["x-gl-developer-description"],
            "The content.",
        )

    def test_strip_prefix_uses_backend_tag(self):
        prefix = "GoogleCloudAiplatformV1beta1"
        schemas = {
            f"{prefix}Candidate": {
                "type": "object",
                "description": "A candidate.",
                "properties": {"index": {"type": "integer"}},
            },
        }
        candidate = strip_prefix_from_schemas(
            schemas, Backend(prefix, "ai-enterprise"), divergences={}
        )["Candidate"]
        self.assertEqual(
            candidate["x-ai-enterprise-original-name"], f"{prefix}Candidate"
        )
        self.assertNotIn("x-gl-developer-original-name", candidate)
        self.assertIn(
            "x-ai-enterprise-description", candidate["properties"]["index"]
        )

    def test_strip_prefix_applies_divergences_on_name_collision(self):
        prefix = "GoogleCloudAiplatformV1beta1"
        schemas = {
            "Blob": {
                "type": "object",
                "properties": {"size": {"type": "integer"}},
            },
            f"{prefix}Blob": {
                "type": "object",
                "properties": {"size": {"type": "string"}},
            },
        }
        divergences = {"Blob": {"size": {"type": "string"}}}
        with contextlib.redirect_stdout(io.StringIO()) as out:
            stripped = strip_prefix_from_schemas(
                schemas,
                Backend(prefix, "ai-enterprise"),
                divergences=divergences,
            )
        self.assertEqual(list(stripped), ["Blob"])
        self.assertEqual(
            stripped["Blob"]["properties"]["size"]["type"], "string"
        )
        self.assertIn("Applied registry resolution override", out.getvalue())

    def test_merge_schemas_combines_backend_provenance(self):
        gl = {
            "type": "object",
            "description": "Developer.",
            "x-gl-developer-original-name": "GlThing",
            "properties": {},
        }
        ai = {
            "type": "object",
            "description": "Enterprise.",
            "x-ai-enterprise-original-name": "AiThing",
            "properties": {},
        }
        merged = merge_schemas("Thing", gl, ai, divergences={})
        self.assertEqual(merged["x-gl-developer-original-name"], "GlThing")
        self.assertEqual(merged["x-ai-enterprise-original-name"], "AiThing")
        self.assertEqual(merged["x-gl-developer-description"], "Developer.")
        self.assertEqual(merged["x-ai-enterprise-description"], "Enterprise.")
        self.assertEqual(
            merged["description"], "Developer.\n\nVariant:\nEnterprise."
        )

    def test_merge_properties_unions_enum_cases(self):
        gl = {
            "type": "string",
            "description": "Reason.",
            "x-gl-developer-description": "Reason.",
            "enum": ["UNSPECIFIED", "STOP", "LANGUAGE"],
            "x-gl-developer-enum": ["UNSPECIFIED", "STOP", "LANGUAGE"],
            "enumDescriptions": ["Unused.", "Stopped.", "Language."],
            "enumDeprecated": [False, True, False],
        }
        ai = {
            "type": "string",
            "description": "Reason.",
            "x-ai-enterprise-description": "Reason.",
            "enum": ["UNSPECIFIED", "STOP", "MODEL_ARMOR"],
            "x-ai-enterprise-enum": ["UNSPECIFIED", "STOP", "MODEL_ARMOR"],
            "enumDescriptions": ["Unused.", "Stopped (AI).", "Armor."],
            "enumDeprecated": [False, False, False],
        }
        merged = merge_properties(
            "Candidate", "finishReason", gl, ai, divergences={}
        )
        self.assertEqual(
            merged["enum"], ["UNSPECIFIED", "STOP", "LANGUAGE", "MODEL_ARMOR"]
        )
        self.assertEqual(
            merged["enumDescriptions"],
            ["Unused.", "Stopped.", "Language.", "Armor."],
        )
        # STOP is deprecated only in the Developer API, so it is not
        # deprecated in the merged enum.
        self.assertEqual(
            merged["enumDeprecated"], [False, False, False, False]
        )
        self.assertEqual(merged["x-gl-developer-enum"], gl["enum"])
        self.assertEqual(merged["x-ai-enterprise-enum"], ai["enum"])

    def test_merge_schemas_unions_standalone_enum_cases(self):
        gl = {
            "type": "string",
            "description": "Harm categories.",
            "x-gl-developer-original-name": "GlHarmCategory",
            "x-gl-developer-description": "Harm categories.",
            "enum": ["HARM_CATEGORY_UNSPECIFIED", "HARM_CATEGORY_DEROGATORY"],
            "x-gl-developer-enum": [
                "HARM_CATEGORY_UNSPECIFIED",
                "HARM_CATEGORY_DEROGATORY",
            ],
            "enumDescriptions": ["Unused.", "Derogatory."],
        }
        ai = {
            "type": "string",
            "description": "Harm categories.",
            "x-ai-enterprise-original-name": "AiHarmCategory",
            "x-ai-enterprise-description": "Harm categories.",
            "enum": ["HARM_CATEGORY_UNSPECIFIED", "HARM_CATEGORY_IMAGE_HATE"],
            "x-ai-enterprise-enum": [
                "HARM_CATEGORY_UNSPECIFIED",
                "HARM_CATEGORY_IMAGE_HATE",
            ],
            "enumDescriptions": ["Unused.", "Image hate."],
        }
        merged = merge_schemas("HarmCategory", gl, ai, divergences={})
        self.assertEqual(
            merged["enum"],
            [
                "HARM_CATEGORY_UNSPECIFIED",
                "HARM_CATEGORY_DEROGATORY",
                "HARM_CATEGORY_IMAGE_HATE",
            ],
        )
        self.assertEqual(
            merged["enumDescriptions"],
            ["Unused.", "Derogatory.", "Image hate."],
        )
        self.assertNotIn("enumDeprecated", merged)
        self.assertEqual(
            merged["x-gl-developer-original-name"], "GlHarmCategory"
        )
        self.assertEqual(
            merged["x-ai-enterprise-original-name"], "AiHarmCategory"
        )

    def test_strip_prefix_annotates_backend_enum_cases(self):
        schemas = {
            "GlModality": {"type": "string", "enum": ["TEXT", "IMAGE"]},
            "GlPart": {
                "type": "object",
                "properties": {
                    "kind": {"type": "string", "enum": ["A", "B"]},
                },
            },
        }
        stripped = strip_prefix_from_schemas(
            schemas, Backend(prefix="Gl", tag="gl-developer"), divergences={}
        )
        self.assertEqual(
            stripped["Modality"]["x-gl-developer-enum"], ["TEXT", "IMAGE"]
        )
        self.assertEqual(
            stripped["Part"]["properties"]["kind"]["x-gl-developer-enum"],
            ["A", "B"],
        )

    def test_rename_schemas_and_refs_applies_acronyms(self):
        schemas = {
            "UrlContext": {"type": "object", "id": "UrlContext"},
            "Tool": {
                "type": "object",
                "properties": {
                    "urlContext": {"$ref": "#/components/schemas/UrlContext"}
                },
            },
        }
        renamed = rename_schemas_and_refs(schemas, {})
        self.assertIn("URLContext", renamed)
        self.assertEqual(renamed["URLContext"]["id"], "URLContext")
        self.assertEqual(
            renamed["Tool"]["properties"]["urlContext"]["$ref"],
            "#/components/schemas/URLContext",
        )


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

import unittest
import sys
import os

# Add scripts directory to path so we can import generate_types
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import generate_types


class TestGenerateTypes(unittest.TestCase):
    def setUp(self):
        # Reset globals before each test to ensure clean test environment
        generate_types.EXCLUDED_SCHEMAS = set()
        generate_types.EXCLUDED_PROPERTIES = {}
        generate_types.SCHEMA_RENAME_MAPPINGS = {}
        generate_types.TYPE_OVERRIDES = {}

    def test_strip_enum_prefix(self):
        # Test basic prefix stripping
        cases = ["MEDIA_RESOLUTION_LOW", "MEDIA_RESOLUTION_MEDIUM", "MEDIA_RESOLUTION_HIGH"]
        prefix, filtered = generate_types.strip_enum_prefix(cases)
        self.assertEqual(prefix, "MEDIA_RESOLUTION_")
        self.assertEqual(filtered, cases)

        # Test fallback when prefix has no underscore
        cases = ["low", "medium", "high"]
        prefix, filtered = generate_types.strip_enum_prefix(cases)
        self.assertEqual(prefix, "")
        self.assertEqual(filtered, cases)

    def test_dotted_namespace_nesting(self):
        # Test nesting under parent namespace when dot is in name
        schema_data = {
            "type": "object",
            "properties": {
                "level": {
                    "type": "string"
                }
            }
        }
        
        resolved = {"Part.MediaResolution": schema_data}
        swift_types = generate_types.process_resolved_schemas(resolved, set(), "GeminiDataModels")
        
        # Verify nested name and namespace separation
        self.assertEqual(len(swift_types), 1)
        st = swift_types[0]
        self.assertEqual(st.name, "MediaResolution")
        self.assertEqual(st.namespace, "GeminiDataModels.Part")
        self.assertEqual(st.kind, "struct")

    def test_auto_exclusion_of_properties(self):
        # Configure EXCLUDED_SCHEMAS to block DynamicRetrievalConfig
        generate_types.EXCLUDED_SCHEMAS = {"DynamicRetrievalConfig"}
        
        schema_data = {
            "type": "object",
            "properties": {
                "dynamicRetrievalConfig": {
                    "$ref": "#/components/schemas/DynamicRetrievalConfig"
                },
                "otherProp": {
                    "type": "string"
                }
            }
        }
        
        resolved = {"GoogleSearchRetrieval": schema_data}
        swift_types = generate_types.process_resolved_schemas(resolved, set(), "GeminiDataModels")
        
        self.assertEqual(len(swift_types), 1)
        st = swift_types[0]
        # Only otherProp should remain generated
        self.assertEqual(len(st.properties), 1)
        self.assertEqual(st.properties[0].swift_name, "otherProp")

    def test_dead_reference_pruning_in_resolver(self):
        # Configure Candidate's groundingAttributions to be excluded
        generate_types.EXCLUDED_PROPERTIES = {
            "Candidate": ["groundingAttributions"]
        }
        
        schemas = {
            "Candidate": {
                "type": "object",
                "properties": {
                    "groundingAttributions": {
                        "type": "array",
                        "items": {
                            "$ref": "#/components/schemas/GroundingAttribution"
                        }
                    },
                    "text": {
                        "type": "string"
                    }
                }
            },
            "GroundingAttribution": {
                "type": "object",
                "properties": {
                    "content": {
                        "type": "string"
                    }
                }
            }
        }
        
        # Resolve starting from Candidate
        resolved = generate_types.resolve_all_types(schemas, ["Candidate"])
        
        # GroundingAttribution should NOT be resolved since Candidate.groundingAttributions was skipped
        self.assertIn("Candidate", resolved)
        self.assertNotIn("GroundingAttribution", resolved)

    def test_standalone_top_level_enum_generation(self):
        schema_data = {
            "type": "string",
            "enum": ["unspecified", "standard", "flex"],
            "enumDescriptions": ["Default", "Standard", "Flexible"]
        }
        
        resolved = {"ServiceTier": schema_data}
        swift_types = generate_types.process_resolved_schemas(resolved, set(), "GeminiDataModels")
        
        self.assertEqual(len(swift_types), 1)
        st = swift_types[0]
        self.assertEqual(st.name, "ServiceTier")
        self.assertEqual(st.kind, "enum")
        self.assertEqual(len(st.cases), 2)  # unspecified is omitted
        self.assertEqual(st.cases[0].swift_name, "standard")
        self.assertEqual(st.cases[0].description, "Standard")

    def test_nullable_types_parsing(self):
        # Verify that nullable types resolve to optional in Swift
        schema_data = {
            "type": "object",
            "properties": {
                "foo": {
                    "type": ["string", "null"]
                }
            }
        }
        resolved = {"Parent": schema_data}
        swift_types = generate_types.process_resolved_schemas(resolved, set(), "GeminiDataModels")
        
        self.assertEqual(len(swift_types), 1)
        st = swift_types[0]
        self.assertEqual(len(st.properties), 1)
        prop = st.properties[0]
        # Since it is not in the required array, it resolves as optional type
        self.assertEqual(prop.swift_type, "String")
        self.assertFalse(prop.is_required)

    def test_schema_merging_order_preservation(self):
        schema1 = {
            "type": "object",
            "properties": {
                "a": {"type": "string"},
                "c": {"type": "string"}
            }
        }
        schema2 = {
            "type": "object",
            "properties": {
                "b": {"type": "string"},
                "a": {"type": "string"}
            }
        }
        
        # Merging schemas should preserve the union order: a, c, b
        merged = generate_types.merge_schemas("Merged", schema1, schema2)
        prop_names = list(merged.get("properties", {}).keys())
        self.assertEqual(prop_names, ["a", "c", "b"])

    def test_structured_docc_formatting(self):
        # Configure original names and descriptions
        prop_data = {
            "x-gl-description": "Gl description.",
            "x-ai-description": "Ai description.",
            "x-gl-original-name": "glName",
            "x-ai-original-name": "aiName"
        }
        docc = generate_types.format_property_docc("prop", prop_data)
        
        # Verify callouts and sections exist
        self.assertIn("Gl description.", docc)
        self.assertIn("Ai description.", docc)
        self.assertIn("### Gemini Developer API", docc)
        self.assertIn("### Gemini Enterprise Agent Platform", docc)


if __name__ == "__main__":
    unittest.main()

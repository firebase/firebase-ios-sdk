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

"""Unit tests for swift_typegen.graph."""

import unittest

from swift_typegen.graph import (
    build_direct_dependency_graph,
    find_cycle_nodes,
    property_ref_target,
    resolve_all_types,
)


class TestGraph(unittest.TestCase):

    def test_dead_reference_pruning_in_resolver(self):
        schemas = {
            "Candidate": {
                "type": "object",
                "properties": {
                    "groundingAttributions": {
                        "type": "array",
                        "items": {
                            "$ref": (
                                "#/components/schemas/GroundingAttribution"
                            )
                        },
                    },
                    "text": {"type": "string"},
                },
            },
            "GroundingAttribution": {
                "type": "object",
                "properties": {"content": {"type": "string"}},
            },
        }
        resolved = resolve_all_types(
            schemas,
            ["Candidate"],
            excluded_schemas=set(),
            excluded_properties={"Candidate": {"groundingAttributions"}},
        )
        self.assertIn("Candidate", resolved)
        self.assertNotIn("GroundingAttribution", resolved)

    def test_resolver_skips_excluded_schemas(self):
        schemas = {
            "Root": {
                "type": "object",
                "properties": {
                    "kept": {"$ref": "#/components/schemas/Kept"},
                    "dropped": {"$ref": "#/components/schemas/Dropped"},
                },
            },
            "Kept": {"type": "object", "properties": {}},
            "Dropped": {"type": "object", "properties": {}},
        }
        resolved = resolve_all_types(
            schemas,
            ["Root"],
            excluded_schemas={"Dropped"},
            excluded_properties={},
        )
        self.assertEqual(set(resolved), {"Root", "Kept"})

    def test_property_ref_target(self):
        self.assertEqual(
            property_ref_target({"$ref": "#/components/schemas/A"}), "A"
        )
        self.assertEqual(
            property_ref_target(
                {"type": "array", "items": {"$ref": "#/components/schemas/B"}}
            ),
            "B",
        )
        self.assertIsNone(property_ref_target({"type": "string"}))
        self.assertIsNone(
            property_ref_target({"type": "array", "items": {"type": "string"}})
        )

    def test_find_cycle_nodes_detects_self_referential_types(self):
        graph = {
            "Schema": {"Schema", "DataType"},
            "DataType": set(),
            "NonCyclic": set(),
        }
        self.assertEqual(find_cycle_nodes(graph), {"Schema"})

        indirect_graph = {
            "A": {"B"},
            "B": {"C"},
            "C": {"A"},
            "D": {"A"},
        }
        self.assertEqual(find_cycle_nodes(indirect_graph), {"A", "B", "C"})

    def test_direct_dependency_graph_ignores_array_indirection(self):
        resolved = {
            "Node": {
                "type": "object",
                "properties": {
                    "children": {
                        "type": "array",
                        "items": {"$ref": "#/components/schemas/Node"},
                    },
                    "leaf": {"$ref": "#/components/schemas/Leaf"},
                },
            },
            "Leaf": {"type": "object", "properties": {}},
        }
        graph = build_direct_dependency_graph(resolved, excluded_properties={})
        self.assertEqual(graph, {"Node": {"Leaf"}, "Leaf": set()})
        self.assertEqual(find_cycle_nodes(graph), set())


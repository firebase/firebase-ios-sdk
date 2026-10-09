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

"""Schema reference traversal, reachability, and cycle detection."""

from __future__ import annotations

from typing import Any


def resolve_ref(ref: str) -> str:
    """Extracts the schema name from an OpenAPI $ref URI.

    Args:
        ref: The OpenAPI reference string (e.g., '#/components/schemas/MyType').

    Returns:
        The target schema name.
    """
    if ref.startswith("#/components/schemas/"):
        return ref.split("/")[-1]
    return ref


def property_ref_target(prop_data: dict[str, Any]) -> str | None:
    """Returns the schema a property references directly or via array items.

    Args:
        prop_data: The property definition dictionary.

    Returns:
        The referenced schema name, or None if the property is not a
        reference or an array of references.
    """
    if "$ref" in prop_data:
        return resolve_ref(prop_data["$ref"])
    if prop_data.get("type") == "array" and "items" in prop_data:
        items_data = prop_data["items"]
        if "$ref" in items_data:
            return resolve_ref(items_data["$ref"])
    return None


def find_refs_in_json(data: Any) -> set[str]:
    """Recursively collects all $ref schema targets within a JSON structure.

    Args:
        data: The JSON structure or schema node to inspect.

    Returns:
        Set of resolved schema names referenced in data.
    """
    refs: set[str] = set()
    if isinstance(data, dict):
        if "$ref" in data and isinstance(data["$ref"], str):
            refs.add(resolve_ref(data["$ref"]))
        for v in data.values():
            refs.update(find_refs_in_json(v))
    elif isinstance(data, list):
        for item in data:
            refs.update(find_refs_in_json(item))
    return refs


def find_refs_in_schema(
    schema_name: str,
    data: dict[str, Any],
    excluded_properties: dict[str, set[str]],
    excluded_schemas: set[str],
) -> set[str]:
    """Collects valid outgoing schema references, skipping excluded properties.

    Args:
        schema_name: The name of the schema containing data.
        data: The schema definition dictionary.
        excluded_properties: Mapping of schema name to excluded property names.
        excluded_schemas: Set of excluded schema names.

    Returns:
        Set of referenced schema names.
    """
    ex_props = excluded_properties
    ex_schemas = excluded_schemas

    refs: set[str] = set()
    if not isinstance(data, dict):
        return refs

    for k, v in data.items():
        if k == "properties" and isinstance(v, dict):
            for prop_name, prop_data in v.items():
                if (
                    schema_name in ex_props
                    and prop_name in ex_props[schema_name]
                ):
                    continue

                if property_ref_target(prop_data) in ex_schemas:
                    continue

                refs.update(find_refs_in_json(prop_data))
        else:
            refs.update(find_refs_in_json(v))

    return refs


def resolve_all_types(
    schemas: dict[str, Any],
    roots: list[str],
    excluded_schemas: set[str],
    excluded_properties: dict[str, set[str]],
) -> dict[str, Any]:
    """Transitively resolves all schemas reachable from root schemas.

    Args:
        schemas: Complete dictionary of available schemas.
        roots: List of root schema names to start traversal from.
        excluded_schemas: Set of schemas to omit.
        excluded_properties: Mapping of schema name to excluded property names.

    Returns:
        Dictionary of all reachable schema definitions.
    """
    ex_schemas = excluded_schemas
    ex_props = excluded_properties

    to_visit = list(roots)
    visited: set[str] = set()
    resolved_schemas: dict[str, Any] = {}

    while to_visit:
        name = to_visit.pop(0)
        if name in visited or name in ex_schemas:
            continue
        visited.add(name)

        schema_data = schemas.get(name)
        if not schema_data:
            continue

        resolved_schemas[name] = schema_data

        for ref in sorted(
            find_refs_in_schema(
                name,
                schema_data,
                excluded_properties=ex_props,
                excluded_schemas=ex_schemas,
            )
        ):
            if ref not in visited:
                to_visit.append(ref)

    return resolved_schemas


def find_direct_refs(data: Any) -> set[str]:
    """Finds direct, non-array references that impose inline struct containment.

    Args:
        data: The schema node to inspect.

    Returns:
        Set of schema names directly referenced without indirection.
    """
    refs: set[str] = set()
    if isinstance(data, dict):
        if data.get("type") == "array" or "additionalProperties" in data:
            return set()
        if "$ref" in data and isinstance(data["$ref"], str):
            refs.add(resolve_ref(data["$ref"]))
        for k, v in data.items():
            if k not in ("items", "additionalProperties"):
                refs.update(find_direct_refs(v))
    elif isinstance(data, list):
        for item in data:
            refs.update(find_direct_refs(item))
    return refs


def get_direct_references(
    schema_name: str,
    schema_data: dict[str, Any],
    excluded_properties: dict[str, set[str]],
) -> set[str]:
    """Finds all direct struct containment references for dependency ordering.

    Args:
        schema_name: Name of the schema.
        schema_data: Definition dictionary for the schema.
        excluded_properties: Mapping of schema name to excluded property names.

    Returns:
        Set of directly contained schema names.
    """
    ex_props = excluded_properties
    refs: set[str] = set()
    if "properties" in schema_data and isinstance(
        schema_data["properties"], dict
    ):
        for prop_name, prop_data in schema_data["properties"].items():
            if schema_name in ex_props and prop_name in ex_props[schema_name]:
                continue
            refs.update(find_direct_refs(prop_data))
    if "oneOf" in schema_data:
        refs.update(find_direct_refs(schema_data["oneOf"]))
    return refs


def build_direct_dependency_graph(
    resolved_schemas: dict[str, Any],
    excluded_properties: dict[str, set[str]],
) -> dict[str, set[str]]:
    """Constructs a direct dependency graph for cyclic containment analysis.

    Args:
        resolved_schemas: Dictionary of resolved schemas.
        excluded_properties: Mapping of schema name to excluded property names.

    Returns:
        Graph mapping schema names to sets of directly contained dependencies.
    """
    graph: dict[str, set[str]] = {}
    for name, data in resolved_schemas.items():
        graph[name] = get_direct_references(name, data, excluded_properties)
    return graph


def find_cycle_nodes(graph: dict[str, set[str]]) -> set[str]:
    """Finds all nodes involved in recursive reference cycles.

    Args:
        graph: Directed dependency graph mapping nodes to neighbors.

    Returns:
        Set of node names that can reach themselves.
    """
    cycle_nodes: set[str] = set()

    def can_reach(start: str, current: str, visited: set[str]) -> bool:
        for neighbor in graph.get(current, set()):
            if neighbor == start:
                return True
            if neighbor not in visited:
                visited.add(neighbor)
                if can_reach(start, neighbor, visited):
                    return True
        return False

    for node in graph:
        if can_reach(node, node, set()):
            cycle_nodes.add(node)

    return cycle_nodes

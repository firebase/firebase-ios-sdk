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

"""Backend spec preprocessing: prefix stripping, renaming, and merging."""

from __future__ import annotations

from typing import Any

from .config import (
    BACKEND_TAGS,
    DEVELOPER_TAG,
    ENTERPRISE_TAG,
    Backend,
    provenance_key,
)
from .docc import VARIANT_SEPARATOR
from .naming import apply_swift_acronyms


def _annotate_backend(
    stripped: dict[str, Any],
    schema_name: str,
    schema_data: dict[str, Any],
    backend_tag: str,
) -> None:
    """Records backend provenance in 'x-<tag>-*' extension fields, in place.

    Args:
        stripped: Prefix-stripped copy of the schema to annotate.
        schema_name: Original (unstripped) schema name.
        schema_data: Original schema definition.
        backend_tag: Backend extension tag (one of BACKEND_TAGS).
    """
    description_key = provenance_key(backend_tag, "description")
    enum_key = provenance_key(backend_tag, "enum")
    props = stripped.get("properties")
    if isinstance(props, dict):
        for p_data in props.values():
            if isinstance(p_data, dict):
                p_data[description_key] = p_data.get("description", "")
                if isinstance(p_data.get("enum"), list):
                    p_data[enum_key] = list(p_data["enum"])
    stripped[provenance_key(backend_tag, "original-name")] = schema_name
    stripped[description_key] = schema_data.get("description", "")
    if isinstance(stripped.get("enum"), list):
        stripped[enum_key] = list(stripped["enum"])


def _ordered_union(lists: list[list[Any]]) -> list[Any]:
    """Returns the distinct items of lists, in first-seen order."""
    result: list[Any] = []
    for items in lists:
        for item in items:
            if item not in result:
                result.append(item)
    return result


def _merge_enums(
    merged: dict[str, Any], first: dict[str, Any], second: dict[str, Any]
) -> None:
    """Unions the enum cases of two definitions into merged, in place.

    Cases keep first-seen order (first's cases, then cases only in second).
    `enumDescriptions` and `enumDeprecated` stay index-aligned with the
    merged cases: descriptions prefer first's text, and a case is deprecated
    only if every definition containing it marks it deprecated. Per-backend
    'x-<tag>-enum' case lists are unioned by tag (not by position) so that
    per-case availability can be documented.

    Args:
        merged: The merged definition to update in place.
        first: First enum definition.
        second: Second enum definition.
    """
    sources = [d for d in (first, second) if isinstance(d.get("enum"), list)]
    if not sources:
        return
    cases = _ordered_union([d["enum"] for d in sources])
    merged["enum"] = cases

    def lookup(data: dict[str, Any], key: str, case: Any) -> Any:
        values = data.get(key)
        if not isinstance(values, list) or case not in data["enum"]:
            return None
        idx = data["enum"].index(case)
        return values[idx] if idx < len(values) else None

    if any("enumDescriptions" in d for d in sources):
        descriptions: list[str] = []
        for case in cases:
            found = [lookup(d, "enumDescriptions", case) for d in sources]
            descriptions.append(next((f for f in found if f), ""))
        merged["enumDescriptions"] = descriptions
    else:
        merged.pop("enumDescriptions", None)

    if any("enumDeprecated" in d for d in sources):
        merged["enumDeprecated"] = [
            all(
                bool(lookup(d, "enumDeprecated", case))
                for d in sources
                if case in d["enum"]
            )
            for case in cases
        ]
    else:
        merged.pop("enumDeprecated", None)

    for tag in BACKEND_TAGS:
        key = provenance_key(tag, "enum")
        tagged = [d[key] for d in (first, second) if key in d]
        if tagged:
            merged[key] = _ordered_union(tagged)


def _merge_descriptions(
    merged: dict[str, Any], first: dict[str, Any], second: dict[str, Any]
) -> None:
    """Sets merged['description'], joining differing texts with a variant."""
    desc1 = first.get("description", "")
    desc2 = second.get("description", "")
    if desc1 and desc2 and desc1 != desc2:
        merged["description"] = f"{desc1}{VARIANT_SEPARATOR}{desc2}"
    elif desc2:
        merged["description"] = desc2


def _merge_provenance(
    merged: dict[str, Any],
    developer: dict[str, Any],
    enterprise: dict[str, Any],
) -> None:
    """Combines per-backend provenance and descriptions into merged.

    Callers must pass the Developer API definition first; see
    pipeline.select_backends, which fixes the merge order.

    Args:
        merged: The merged definition to update in place.
        developer: Definition from the Gemini Developer API (first) backend.
        enterprise: Definition from the Gemini Enterprise Agent Platform
            (second) backend.
    """
    by_tag = (
        (DEVELOPER_TAG, developer, enterprise),
        (ENTERPRISE_TAG, enterprise, developer),
    )
    for tag, own, other in by_tag:
        name_key = provenance_key(tag, "original-name")
        if name_key in own:
            merged[name_key] = own[name_key]
        elif name_key in other:
            merged[name_key] = other[name_key]

    for tag, own, _ in by_tag:
        description_key = provenance_key(tag, "description")
        merged[description_key] = own.get(description_key) or own.get(
            "description", ""
        )
    _merge_descriptions(merged, developer, enterprise)


def strip_prefix_from_schemas(
    schemas: dict[str, Any],
    backend: Backend,
    divergences: dict[str, Any],
) -> dict[str, Any]:
    """Strips a backend vendor prefix from schema names and $ref targets.

    Annotates original names and descriptions in 'x-<tag>-*' extension fields
    (see config.provenance_key) for backend divergence tracking.

    Args:
        schemas: Dictionary of schemas.
        backend: Backend whose prefix to strip and tag to annotate with.
        divergences: Divergence resolutions keyed by schema, then property,
            applied when a stripped name collides with an unprefixed schema.

    Returns:
        Dictionary with stripped schema keys and updated $ref pointers.
    """
    prefix = backend.prefix
    backend_tag = backend.tag

    def strip_prefix_from_value(val: Any) -> Any:
        if isinstance(val, dict):
            new_dict: dict[str, Any] = {}
            for k, v in val.items():
                if k == "$ref" and isinstance(v, str):
                    if v.startswith("#/components/schemas/"):
                        ref_name = v.split("/")[-1]
                        if ref_name.startswith(prefix):
                            ref_name = ref_name[len(prefix) :]
                        new_dict[k] = f"#/components/schemas/{ref_name}"
                    elif v.startswith(prefix):
                        new_dict[k] = v[len(prefix) :]
                    else:
                        new_dict[k] = v
                else:
                    new_dict[k] = strip_prefix_from_value(v)
            return new_dict
        elif isinstance(val, list):
            return [strip_prefix_from_value(item) for item in val]
        return val

    new_schemas: dict[str, Any] = {}

    for schema_name, schema_data in schemas.items():
        if not schema_name.startswith(prefix):
            stripped = strip_prefix_from_value(schema_data)
            if isinstance(stripped, dict):
                _annotate_backend(stripped, schema_name, schema_data, backend_tag)
            new_schemas[schema_name] = stripped

    for schema_name, schema_data in schemas.items():
        if schema_name.startswith(prefix):
            new_name = schema_name[len(prefix) :]
            stripped = strip_prefix_from_value(schema_data)
            if isinstance(stripped, dict):
                _annotate_backend(stripped, schema_name, schema_data, backend_tag)
            if new_name in new_schemas:
                new_schemas[new_name] = merge_schemas(
                    new_name,
                    new_schemas[new_name],
                    stripped,
                    divergences=divergences,
                )
            else:
                new_schemas[new_name] = stripped

    return new_schemas


def rename_schemas_and_refs(
    schemas: dict[str, Any], mappings: dict[str, str]
) -> dict[str, Any]:
    """Applies schema renaming and updates all $ref pointers.

    Also derives acronym-cased names so that references update automatically.

    Args:
        schemas: Dictionary of schemas.
        mappings: Mapping from original schema name to replacement name.

    Returns:
        Dictionary of schemas with updated names and references.
    """
    effective_mappings = dict(mappings)
    for s_name in list(schemas.keys()):
        acronym_name = apply_swift_acronyms(s_name, is_type=True)
        if acronym_name != s_name and s_name not in effective_mappings:
            effective_mappings[s_name] = acronym_name

    if not effective_mappings:
        return schemas

    def rename_refs_in_value(val: Any) -> Any:
        if isinstance(val, dict):
            new_dict: dict[str, Any] = {}
            for k, v in val.items():
                if k == "$ref" and isinstance(v, str):
                    if v.startswith("#/components/schemas/"):
                        ref_name = v.split("/")[-1]
                        if ref_name in effective_mappings:
                            new_ref = effective_mappings[ref_name]
                            new_dict[k] = f"#/components/schemas/{new_ref}"
                        else:
                            new_dict[k] = v
                    elif v in effective_mappings:
                        new_dict[k] = effective_mappings[v]
                    else:
                        new_dict[k] = v
                else:
                    new_dict[k] = rename_refs_in_value(v)
            return new_dict
        elif isinstance(val, list):
            return [rename_refs_in_value(item) for item in val]
        return val

    new_schemas: dict[str, Any] = {}
    for schema_name, schema_data in schemas.items():
        new_name = effective_mappings.get(schema_name, schema_name)
        new_schemas[new_name] = rename_refs_in_value(schema_data)
        if "id" in new_schemas[new_name] and isinstance(
            new_schemas[new_name]["id"], str
        ):
            curr_id = new_schemas[new_name]["id"]
            new_schemas[new_name]["id"] = effective_mappings.get(
                curr_id, curr_id
            )

    return new_schemas


def merge_properties(
    parent_name: str,
    prop_name: str,
    prop1: dict[str, Any],
    prop2: dict[str, Any],
    divergences: dict[str, Any],
) -> dict[str, Any]:
    """Merges two property definitions across backends.

    Args:
        parent_name: Schema name containing the property.
        prop_name: Property name.
        prop1: First property definition.
        prop2: Second property definition.
        divergences: Divergence resolutions keyed by schema, then property.

    Returns:
        Merged property definition dictionary.
    """
    if parent_name in divergences and prop_name in divergences[parent_name]:
        override = divergences[parent_name][prop_name]
        merged = dict(prop1)
        merged.update(override)
        _merge_descriptions(merged, prop1, prop2)
        print(
            f"Info: Applied registry resolution override for property"
            f" '{prop_name}' in '{parent_name}' -> {override}"
        )
        return merged

    if prop1 == prop2:
        return prop1

    merged = dict(prop1)
    _merge_provenance(merged, prop1, prop2)
    _merge_enums(merged, prop1, prop2)

    t1 = prop1.get("type")
    t2 = prop2.get("type")

    if t1 != t2:
        numeric_types = {"integer", "number"}
        if t1 in numeric_types and t2 in numeric_types:
            print(
                f"Warning: Promoting numeric types for property '{prop_name}'"
                f" in schema '{parent_name}': {t1} vs {t2}"
            )
            merged["type"] = "number"
            if "format" in merged:
                merged.pop("format")
        else:
            print(
                f"Warning: Type conflict for property '{prop_name}' in schema"
                f" '{parent_name}': {t1} vs {t2}"
            )

    f1 = prop1.get("format")
    f2 = prop2.get("format")
    if f1 != f2 and f1 and f2:
        if "format" in merged:
            merged.pop("format")

    ref1 = prop1.get("$ref")
    ref2 = prop2.get("$ref")
    if ref1 != ref2:
        print(
            f"Warning: Ref conflict for property '{prop_name}' in schema"
            f" '{parent_name}': {ref1} vs {ref2}"
        )

    if (
        t1 == "array"
        and t2 == "array"
        and "items" in prop1
        and "items" in prop2
    ):
        merged["items"] = merge_properties(
            parent_name,
            f"{prop_name}.items",
            prop1["items"],
            prop2["items"],
            divergences=divergences,
        )

    if (
        t1 == "object"
        and t2 == "object"
        and "properties" in prop1
        and "properties" in prop2
    ):
        merged_sub_props: dict[str, Any] = {}
        sub_props1 = prop1.get("properties", {})
        sub_props2 = prop2.get("properties", {})

        all_sub_names: list[str] = []
        seen_sub: set[str] = set()
        for sub_name in list(sub_props1.keys()) + list(sub_props2.keys()):
            if sub_name not in seen_sub:
                seen_sub.add(sub_name)
                all_sub_names.append(sub_name)

        for sub_name in all_sub_names:
            if sub_name in sub_props1 and sub_name in sub_props2:
                merged_sub_props[sub_name] = merge_properties(
                    parent_name,
                    f"{prop_name}.{sub_name}",
                    sub_props1[sub_name],
                    sub_props2[sub_name],
                    divergences=divergences,
                )
            elif sub_name in sub_props1:
                merged_sub_props[sub_name] = sub_props1[sub_name]
            else:
                merged_sub_props[sub_name] = sub_props2[sub_name]
        merged["properties"] = merged_sub_props

    return merged


def merge_schemas(
    name: str,
    schema1: dict[str, Any],
    schema2: dict[str, Any],
    divergences: dict[str, Any],
) -> dict[str, Any]:
    """Merges two schema definitions for identical schema names across backends.

    Args:
        name: Name of the schema.
        schema1: First schema definition.
        schema2: Second schema definition.
        divergences: Divergence resolutions keyed by schema, then property.

    Returns:
        Merged schema definition dictionary.
    """
    if isinstance(schema1.get("enum"), list) and isinstance(
        schema2.get("enum"), list
    ):
        merged = dict(schema1)
        _merge_provenance(merged, schema1, schema2)
        _merge_enums(merged, schema1, schema2)
        return merged

    if schema1.get("type") != "object" or schema2.get("type") != "object":
        return schema1

    merged = dict(schema1)
    _merge_provenance(merged, schema1, schema2)

    props1 = schema1.get("properties", {})
    props2 = schema2.get("properties", {})
    all_prop_names = sorted(set(props1.keys()) | set(props2.keys()))

    merged_props: dict[str, Any] = {}
    for prop_name in all_prop_names:
        if prop_name in props1 and prop_name in props2:
            merged_props[prop_name] = merge_properties(
                name,
                prop_name,
                props1[prop_name],
                props2[prop_name],
                divergences=divergences,
            )
        elif prop_name in props1:
            merged_props[prop_name] = props1[prop_name]
        else:
            merged_props[prop_name] = props2[prop_name]

    merged["properties"] = merged_props
    return merged

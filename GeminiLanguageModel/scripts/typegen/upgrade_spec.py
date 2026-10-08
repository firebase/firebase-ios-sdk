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

"""Converts Discovery Document JSON to OpenAPI 3.1.0 specification YAML."""

from __future__ import annotations

import argparse
from collections.abc import Sequence
import copy
import json
import os
import sys
from typing import Any, Callable
import urllib.request

import yaml

from swift_typegen.config import GeneratorConfig

DISCOVERY_URL = (
    "https://firebasevertexai.googleapis.com/$discovery/rest?version=v1beta"
)

STANDALONE_ENUM_RULES: list[dict[str, Any]] = [
    {
        "pattern": (
            lambda s_name, p_name, cases: bool(
                cases and cases[0].startswith("HARM_CATEGORY_")
            )
        ),
        "name_fn": lambda prefix: f"{prefix}HarmCategory",
        "description": "Harm categories for safety settings and ratings.",
    },
    {
        "pattern": (
            lambda s_name, p_name, cases: bool(
                cases and cases[0].startswith("MODALITY_")
            )
        ),
        "name_fn": lambda prefix: f"{prefix}Modality",
        "description": "Content modalities.",
    },
    {
        "pattern": (
            lambda s_name, p_name, cases: bool(
                p_name == "type" and cases and cases[0] == "TYPE_UNSPECIFIED"
            )
        ),
        "name_fn": lambda prefix: f"{prefix}Type",
        "description": "Schema data types.",
    },
    {
        "pattern": (
            lambda s_name, p_name, cases: bool(
                cases and cases[0].startswith("TOOL_TYPE_")
            )
        ),
        "name_fn": lambda prefix: "ToolType",
        "description": "Tool types for function calling and tools.",
    },
    {
        "pattern": (
            lambda s_name, p_name, cases: bool(
                p_name == "serviceTier" and "standard" in cases
            )
        ),
        "name_fn": lambda prefix: f"{prefix}ServiceTier",
        "description": "Service tier for request processing.",
    },
    {
        "pattern": (
            lambda s_name, p_name, cases: bool(
                p_name in ("stage", "modelStage")
                or (cases and cases[0].startswith(("STAGE_", "MODEL_STAGE_")))
            )
        ),
        "name_fn": lambda prefix: f"{prefix}ModelStage",
        "description": "Model lifecycle stages.",
    },
]


def normalize_refs(node: Any) -> None:
    """Recursively converts Discovery $ref to OpenAPI format in-place.

    Converts raw Discovery format $ref ("SchemaName") to OpenAPI format
    ("#/components/schemas/SchemaName").

    Args:
        node: The JSON or schema node to normalize.
    """
    if isinstance(node, dict):
        if "$ref" in node and isinstance(node["$ref"], str):
            ref = node["$ref"]
            if not ref.startswith("#/"):
                node["$ref"] = f"#/components/schemas/{ref}"
        for v in node.values():
            normalize_refs(v)
    elif isinstance(node, list):
        for item in node:
            normalize_refs(item)


def extract_standalone_enums(
    schemas: dict[str, Any], prefixes: Sequence[str]
) -> None:
    """Extracts shared inline enums into standalone top-level schemas.

    Heuristically identifies inline enums matching STANDALONE_ENUM_RULES,
    converts them into standalone top-level schemas, and updates referring
    properties and array items to reference them via $ref.

    Args:
        schemas: Dictionary mapping schema names to schema definitions.
        prefixes: Backend schema name prefixes (generatorConfig.backends).
            Extracted enums are named with the prefix of the schema they
            were found in, so each backend gets its own standalone enum.
    """
    extracted: dict[str, Any] = {}
    for s_name, s_data in list(schemas.items()):
        if not isinstance(s_data, dict) or "properties" not in s_data:
            continue
        prefix = next((p for p in prefixes if s_name.startswith(p)), "")

        for p_name, p_data in list(s_data["properties"].items()):
            if not isinstance(p_data, dict):
                continue
            is_array = (
                p_data.get("type") == "array"
                and "items" in p_data
                and isinstance(p_data["items"], dict)
                and "enum" in p_data["items"]
            )
            has_direct_enum = "enum" in p_data
            if not has_direct_enum and not is_array:
                continue

            target_dict = p_data["items"] if is_array else p_data
            cases = target_dict.get("enum", [])
            rule_matched = None
            for rule in STANDALONE_ENUM_RULES:
                if rule["pattern"](s_name, p_name, cases):
                    rule_matched = rule
                    break
            if not rule_matched:
                continue

            enum_schema_name = rule_matched["name_fn"](prefix)
            if (
                enum_schema_name not in extracted
                and enum_schema_name not in schemas
            ):
                enum_schema: dict[str, Any] = {
                    "type": "string",
                    "enum": list(cases),
                    "description": rule_matched.get(
                        "description", f"{enum_schema_name} values."
                    ),
                }
                if "enumDescriptions" in target_dict:
                    enum_schema["enumDescriptions"] = list(
                        target_dict["enumDescriptions"]
                    )
                if "enumDeprecated" in target_dict:
                    enum_schema["enumDeprecated"] = list(
                        target_dict["enumDeprecated"]
                    )
                extracted[enum_schema_name] = enum_schema
            elif enum_schema_name in extracted:
                existing = extracted[enum_schema_name]
                existing_cases = existing.get("enum", [])
                if len(cases) > len(existing_cases):
                    existing["enum"] = list(cases)
                    if "enumDescriptions" in target_dict:
                        existing["enumDescriptions"] = list(
                            target_dict["enumDescriptions"]
                        )
                    else:
                        existing.pop("enumDescriptions", None)
                    if "enumDeprecated" in target_dict:
                        existing["enumDeprecated"] = list(
                            target_dict["enumDeprecated"]
                        )
                    else:
                        existing.pop("enumDeprecated", None)
                elif cases == existing_cases:
                    if len(target_dict.get("enumDescriptions", [])) > len(
                        existing.get("enumDescriptions", [])
                    ):
                        existing["enumDescriptions"] = list(
                            target_dict["enumDescriptions"]
                        )
                    if len(target_dict.get("enumDeprecated", [])) > len(
                        existing.get("enumDeprecated", [])
                    ):
                        existing["enumDeprecated"] = list(
                            target_dict["enumDeprecated"]
                        )

            prop_desc = p_data.get("description")
            if is_array:
                p_data["items"] = {
                    "$ref": f"#/components/schemas/{enum_schema_name}"
                }
            else:
                new_prop: dict[str, Any] = {
                    "$ref": f"#/components/schemas/{enum_schema_name}"
                }
                if prop_desc:
                    new_prop["description"] = prop_desc
                s_data["properties"][p_name] = new_prop

    schemas.update(extracted)


def infer_required_properties(schemas: dict[str, Any]) -> None:
    """Infers required fields from property descriptions in-place.

    Looks for descriptions beginning with 'Required.' or 'Required:' and
    appends the property name to the schema's required list.

    Args:
        schemas: Dictionary mapping schema names to schema definitions.
    """
    for _, s_data in schemas.items():
        if not isinstance(s_data, dict) or "properties" not in s_data:
            continue
        req: list[str] = s_data.setdefault("required", [])
        for p_name, p_data in s_data["properties"].items():
            if not isinstance(p_data, dict):
                continue
            desc = p_data.get("description", "").strip()
            if desc.startswith("Required.") or desc.startswith("Required:"):
                if p_name not in req:
                    req.append(p_name)


def upgrade_nullables(node: Any) -> None:
    """Recursively converts OpenAPI nullable: true to OpenAPI 3.1.0 format.

    Replaces 'nullable: true' with 'type: [type, "null"]' or converts $ref
    to a oneOf null union in-place.

    Args:
        node: The schema object or tree node to convert.
    """
    if isinstance(node, dict):
        if node.get("nullable") is True:
            if "type" in node:
                t = node["type"]
                if isinstance(t, str):
                    node["type"] = [t, "null"]
                elif isinstance(t, list) and "null" not in t:
                    node["type"] = t + ["null"]
            elif "$ref" in node:
                ref = node.pop("$ref")
                node["oneOf"] = [{"$ref": ref}, {"type": "null"}]
            node.pop("nullable", None)

        for _, v in list(node.items()):
            upgrade_nullables(v)
    elif isinstance(node, list):
        for item in node:
            upgrade_nullables(item)


def simplify_all_of(node: Any) -> None:
    """Recursively simplifies single-element allOf wrappers containing a $ref.

    OpenAPI 3.1.0 allows sibling fields next to $ref, so single-element allOf
    wrappers are redundant and can be unwrapped in-place.

    Args:
        node: The schema object or tree node to simplify.
    """
    if isinstance(node, dict):
        if (
            "allOf" in node
            and isinstance(node["allOf"], list)
            and len(node["allOf"]) == 1
        ):
            item = node["allOf"][0]
            if isinstance(item, dict) and "$ref" in item and len(item) == 1:
                ref = item["$ref"]
                node.pop("allOf")
                node["$ref"] = ref

        for _, v in list(node.items()):
            simplify_all_of(v)
    elif isinstance(node, list):
        for item in node:
            simplify_all_of(item)


def deep_merge(
    source: dict[str, Any], destination: dict[str, Any]
) -> dict[str, Any]:
    """Deep merges source dict into destination dict in-place.

    If a $ref is present in the destination after merging, removes 'type' and
    'items' keys to maintain OpenAPI reference validity.

    Args:
        source: The dictionary containing overriding keys.
        destination: The target dictionary to merge into.

    Returns:
        The mutated destination dictionary.
    """
    for key, value in source.items():
        if isinstance(value, dict):
            node = destination.setdefault(key, {})
            deep_merge(value, node)
        else:
            destination[key] = value

    if "$ref" in destination:
        destination.pop("type", None)
        destination.pop("items", None)

    return destination


def main(argv: list[str] | None = None) -> None:
    """CLI entry point for Discovery Document to OpenAPI 3.1.0 conversion."""
    base_dir = os.path.dirname(os.path.abspath(__file__))
    docs_dir = os.path.join(base_dir, "discovery_documents")

    parser = argparse.ArgumentParser(
        description="Convert Google Discovery Document to OpenAPI 3.1.0."
    )
    parser.add_argument(
        "--input-file",
        default=os.path.join(
            docs_dir, "firebasevertexai_discovery_v1beta.json"
        ),
        help="Path to the Google Discovery Document JSON file.",
    )
    parser.add_argument(
        "--output-file",
        default=os.path.join(docs_dir, "firebasevertexai-openapi.yaml"),
        help="Path to output the converted OpenAPI 3.1.0 YAML specification.",
    )
    parser.add_argument(
        "--overrides-file",
        default=os.path.join(docs_dir, "firebasevertexai-overrides.yaml"),
        help="Path to the overrides YAML file.",
    )
    parser.add_argument(
        "--fetch",
        action="store_true",
        help="Fetch latest Discovery Document live from Google APIs.",
    )
    parser.add_argument(
        "--discovery-url",
        default=DISCOVERY_URL,
        help="URL of the Discovery Document to fetch.",
    )
    args = parser.parse_args(argv)

    if not os.path.exists(args.overrides_file):
        raise FileNotFoundError(
            f"Overrides file not found at {args.overrides_file}"
        )

    if args.fetch or not os.path.exists(args.input_file):
        print(
            "Fetching latest Discovery Document from"
            f" {args.discovery_url}..."
        )
        req = urllib.request.Request(
            args.discovery_url,
            headers={"User-Agent": "Firebase-Type-Generator/1.0"},
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            content = resp.read()
        doc_json = json.loads(content.decode("utf-8"))
        os.makedirs(
            os.path.dirname(os.path.abspath(args.input_file)), exist_ok=True
        )
        with open(args.input_file, "w", encoding="utf-8") as f:
            json.dump(doc_json, f, indent=2, sort_keys=True)
        print(f"Saved live Discovery Document to {args.input_file}")

    # 1. Load Discovery Document
    print(f"Loading Discovery Document from {args.input_file}...")
    with open(args.input_file, "r", encoding="utf-8") as f:
        doc = json.load(f)

    raw_schemas = copy.deepcopy(doc.get("schemas", {}))

    # 2. Build OpenAPI 3.1 envelope
    spec: dict[str, Any] = {
        "openapi": "3.1.0",
        "info": {
            "title": doc.get("title", "Firebase AI Logic API"),
            "description": doc.get(
                "description", "Firebase AI Logic Discovery Document"
            ),
            "version": doc.get("version", "v1beta"),
        },
        "components": {"schemas": raw_schemas},
    }

    schemas = spec["components"]["schemas"]

    # 3. Normalize references
    print("Normalizing schema references...")
    normalize_refs(schemas)

    # 4. Extract shared standalone enums, named per configured backend
    print("Extracting shared standalone enums...")
    backends = GeneratorConfig.from_file(args.overrides_file).backends
    extract_standalone_enums(schemas, prefixes=[b.prefix for b in backends])

    # 5. Infer required properties
    print("Inferring required properties...")
    infer_required_properties(schemas)

    # 6. Upgrade nullables if any
    print("Upgrading nullables...")
    upgrade_nullables(spec)

    # 7. Simplify allOf wrappers if any
    print("Simplifying allOf wrappers...")
    simplify_all_of(spec)

    # 8. Load and apply overrides
    print(f"Applying manual overrides from {args.overrides_file}...")
    with open(args.overrides_file, "r", encoding="utf-8") as f:
        overrides = yaml.safe_load(f)

    if overrides and "schemas" in overrides:
        deep_merge(overrides["schemas"], schemas)

    # 9. Sort schemas and their properties deterministically
    print("Sorting schemas and properties deterministically...")
    sorted_schemas: dict[str, Any] = {}
    for s_name in sorted(schemas.keys()):
        s_data = schemas[s_name]
        if (
            isinstance(s_data, dict)
            and "properties" in s_data
            and isinstance(s_data["properties"], dict)
        ):
            s_data["properties"] = dict(sorted(s_data["properties"].items()))
        sorted_schemas[s_name] = s_data
    spec["components"]["schemas"] = sorted_schemas

    # 10. Output upgraded spec as YAML
    print(
        "Saving upgraded OpenAPI 3.1.0 specification to"
        f" {args.output_file}..."
    )
    with open(args.output_file, "w", encoding="utf-8") as f:
        yaml.safe_dump(spec, f, sort_keys=False, default_flow_style=False)

    print("Upgrade completed successfully.")


if __name__ == "__main__":
    main()

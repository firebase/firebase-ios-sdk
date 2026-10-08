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

"""Converts resolved OpenAPI schemas into Swift type models."""

from __future__ import annotations

import os
from typing import Any

from .config import GeneratorConfig
from .docc import (
    format_enum_case_docc,
    format_init_description,
    format_property_docc,
    format_schema_docc,
)
from .graph import property_ref_target, resolve_ref
from .models import SwiftEnumCase, SwiftProperty, SwiftType
from .naming import to_camel_case


def get_primitive_type(prop_data: dict[str, Any]) -> str | None:
    """Maps OpenAPI primitive types and formats to Swift standard types.

    Args:
        prop_data: The property definition dictionary.

    Returns:
        The corresponding Swift type string, or None if not primitive.
    """
    t = prop_data.get("type")
    if isinstance(t, list):
        t_non_null = [item for item in t if item != "null"]
        t = t_non_null[0] if t_non_null else None

    fmt = prop_data.get("format")
    if t == "string":
        if fmt in ("google-datetime", "date-time", "google-duration"):
            return "String"
        elif fmt == "byte":
            return "Data"
        else:
            return "String"
    elif t == "integer":
        return "Int"
    elif t == "number":
        return "Double"
    elif t == "boolean":
        return "Bool"
    elif t == "any":
        return "JSONValue"
    return None


def strip_enum_prefix(cases: list[str]) -> tuple[str, list[str]]:
    """Identifies and strips shared prefixes from enum cases.

    Args:
        cases: Raw list of enum case strings.

    Returns:
        Tuple of (common prefix string, filtered cases without UNSPECIFIED).
    """
    filtered_cases = [
        c
        for c in cases
        if not (
            c.endswith("_UNSPECIFIED")
            or c.endswith("_UNKNOWN")
            or c == "UNSPECIFIED"
            or c == "UNKNOWN"
        )
    ]
    if not filtered_cases:
        return "", cases

    prefix = os.path.commonprefix(filtered_cases)
    if prefix and "_" in prefix:
        last_underscore = prefix.rfind("_")
        prefix = prefix[: last_underscore + 1]
    else:
        prefix = ""
    return prefix, filtered_cases


class SchemaProcessor:
    """Processes resolved OpenAPI schemas into structured Swift type models."""

    def __init__(
        self,
        config: GeneratorConfig,
        doc_wrap_width: int = 100,
    ) -> None:
        """Initializes the processor with configuration and formatting bounds.

        Args:
            config: GeneratorConfig containing overrides and exclusions.
            doc_wrap_width: Column width for DocC text wrapping.
        """
        self.config = config
        self.doc_wrap_width = doc_wrap_width
        self.top_wrap_width = max(20, doc_wrap_width - 4)
        self.member_wrap_width = max(20, doc_wrap_width - 6)
        self.swift_types: list[SwiftType] = []

    def process(
        self, resolved_schemas: dict[str, Any], namespace: str = ""
    ) -> list[SwiftType]:
        """Processes resolved schemas into a list of SwiftType instances.

        Args:
            resolved_schemas: Dictionary mapping schema names to definitions.
            namespace: Root Swift namespace.

        Returns:
            List of generated SwiftType instances.
        """
        self.swift_types = []
        for name in sorted(resolved_schemas.keys()):
            self._process_schema(
                name, resolved_schemas[name], namespace, resolved_schemas
            )
        return self.swift_types

    def _process_schema(
        self,
        name: str,
        data: dict[str, Any],
        namespace: str,
        resolved_schemas: dict[str, Any],
    ) -> None:
        actual_name = name
        actual_namespace = namespace or ""
        if "." in name:
            name_parts = name.split(".")
            actual_name = name_parts[-1]
            parent_parts = name_parts[:-1]
            if namespace:
                actual_namespace = f"{namespace}." + ".".join(parent_parts)
            else:
                actual_namespace = ".".join(parent_parts)

        if "enum" in data:
            self._process_enum(name, data, actual_name, actual_namespace)
            return

        self._process_struct(
            name, data, actual_name, actual_namespace, resolved_schemas
        )

    def _process_enum(
        self,
        name: str,
        data: dict[str, Any],
        actual_name: str,
        actual_namespace: str,
    ) -> None:
        cases = self._build_enum_cases(data)

        enum_st = SwiftType(
            name=actual_name,
            namespace=actual_namespace,
            kind="enum",
            description=format_schema_docc(
                data, wrap_width=self.top_wrap_width
            ),
            is_deprecated=data.get("deprecated", False),
        )
        enum_st.cases = cases
        self.swift_types.append(enum_st)

    def _process_struct(
        self,
        name: str,
        data: dict[str, Any],
        actual_name: str,
        actual_namespace: str,
        resolved_schemas: dict[str, Any],
    ) -> None:
        st = SwiftType(
            name=actual_name,
            namespace=actual_namespace,
            kind="struct",
            description=format_schema_docc(
                data, wrap_width=self.top_wrap_width
            ),
            is_deprecated=data.get("deprecated", False),
        )

        oneof_options = data.get("oneOf", [])
        oneof_keys: set[str] = set()
        if oneof_options:
            for option in oneof_options:
                if "required" in option and isinstance(
                    option["required"], list
                ):
                    oneof_keys.update(option["required"])

        if oneof_keys:
            st.has_oneof = True
            st.oneof_name = f"{actual_name}Data"

        properties = data.get("properties", {})
        required_props = data.get("required", [])

        for prop_name, prop_data in properties.items():
            if (
                name in self.config.excluded_properties
                and prop_name in self.config.excluded_properties[name]
            ):
                continue

            ref_target = property_ref_target(prop_data)
            if ref_target in self.config.excluded_schemas:
                continue

            swift_prop_name = to_camel_case(prop_name, lower=True)

            # A single-value enum is treated as a constant, so it is detected
            # before the enum branch to avoid emitting an unused nested enum.
            const_val = prop_data.get("const")
            if (
                const_val is None
                and isinstance(prop_data.get("enum"), list)
                and len(prop_data["enum"]) == 1
            ):
                const_val = prop_data["enum"][0]

            if const_val is not None:
                swift_type_str = ""  # Set from const_val below.

            elif "enum" in prop_data:
                enum_name = to_camel_case(prop_name, lower=False)
                enum_namespace = (
                    f"{actual_namespace}.{actual_name}"
                    if actual_namespace
                    else actual_name
                )
                cases = self._build_enum_cases(prop_data)

                enum_st = SwiftType(
                    name=enum_name,
                    namespace=enum_namespace,
                    kind="enum",
                    description=format_property_docc(
                        prop_data, wrap_width=self.member_wrap_width
                    ),
                    is_deprecated=prop_data.get("deprecated", False),
                )
                enum_st.cases = cases
                self.swift_types.append(enum_st)
                swift_type_str = enum_name

            elif (
                prop_data.get("type") == "object"
                and "properties" in prop_data
            ):
                nested_name = to_camel_case(prop_name, lower=False)
                nested_namespace = (
                    f"{actual_namespace}.{actual_name}"
                    if actual_namespace
                    else actual_name
                )
                self._process_schema(
                    nested_name,
                    prop_data,
                    nested_namespace,
                    resolved_schemas,
                )
                swift_type_str = nested_name

            else:
                swift_type_str = self._resolve_swift_type_string(
                    prop_name, prop_data, actual_name, actual_namespace
                )

            is_prop_deprecated = bool(prop_data.get("deprecated", False))
            if not is_prop_deprecated and ref_target in resolved_schemas:
                is_prop_deprecated = bool(
                    resolved_schemas[ref_target].get("deprecated", False)
                )

            is_const = False
            const_value: str | None = None
            if const_val is not None:
                is_const = True
                if isinstance(const_val, bool):
                    swift_type_str = "Bool"
                    const_value = "true" if const_val else "false"
                elif isinstance(const_val, int):
                    swift_type_str = "Int"
                    const_value = str(const_val)
                elif isinstance(const_val, float):
                    swift_type_str = "Double"
                    const_value = str(const_val)
                elif isinstance(const_val, str):
                    swift_type_str = "String"
                    const_value = f'"{const_val}"'
                else:
                    swift_type_str = "JSONValue"
                    const_value = "nil"

            init_desc = format_init_description(prop_data, swift_prop_name)

            prop = SwiftProperty(
                swift_name=swift_prop_name,
                json_name=prop_name,
                swift_type=swift_type_str,
                description=format_property_docc(
                    prop_data, wrap_width=self.member_wrap_width
                ),
                init_description=init_desc,
                is_deprecated=is_prop_deprecated,
                is_required=True
                if is_const
                else (prop_name in required_props),
                is_const=is_const,
                const_value=const_value,
            )

            if prop_name in oneof_keys:
                st.oneof_properties.append(prop)
            else:
                st.properties.append(prop)

        st.properties.sort(key=lambda p: p.swift_name)
        st.oneof_properties.sort(key=lambda p: p.swift_name)
        self.swift_types.append(st)

    def _resolve_swift_type_string(
        self,
        prop_name: str,
        prop_data: dict[str, Any],
        parent_name: str,
        namespace: str,
    ) -> str:
        full_key = f"{parent_name}.{prop_name}" if parent_name else prop_name
        if full_key in self.config.property_type_overrides:
            return self.config.property_type_overrides[full_key]
        if prop_name in self.config.property_type_overrides:
            return self.config.property_type_overrides[prop_name]

        prim = get_primitive_type(prop_data)
        if prim:
            return prim

        if "$ref" in prop_data:
            ref = resolve_ref(prop_data["$ref"])
            return self.config.type_overrides.get(ref, ref)

        if prop_data.get("type") == "array":
            items_data = prop_data.get("items", {})
            item_type = self._resolve_swift_type_string(
                prop_name, items_data, parent_name, namespace
            )
            return f"[{item_type}]"

        if prop_data.get("type") == "object":
            add_props = prop_data.get("additionalProperties", {})
            val_type = self._resolve_swift_type_string(
                prop_name, add_props, parent_name, namespace
            )
            if val_type == "JSONValue":
                return "JSONObject"
            return f"[String: {val_type}]"

        return "JSONValue"

    def _build_enum_cases(self, data: dict[str, Any]) -> list[SwiftEnumCase]:
        """Builds Swift enum cases from an OpenAPI enum definition.

        Skips UNSPECIFIED/UNKNOWN sentinel values and strips the shared
        SCREAMING_CASE prefix from case names.

        Args:
            data: Schema or property definition containing an 'enum' list.

        Returns:
            List of SwiftEnumCase instances in declaration order.
        """
        enum_deprecated_list = data.get(
            "enumDeprecated", data.get("x-google-enum-deprecated", [])
        )
        enum_descriptions = data.get(
            "enumDescriptions", data.get("x-google-enum-descriptions", [])
        )

        cases: list[SwiftEnumCase] = []
        prefix, _ = strip_enum_prefix(data["enum"])
        # Per-backend case lists are only meaningful when the enum was merged
        # from both backends; otherwise availability is documented at the
        # type or property level.
        gl_cases = data.get("x-gl-enum")
        ai_cases = data.get("x-ai-enum")
        track_backends = gl_cases is not None and ai_cases is not None

        for idx, raw_val in enumerate(data["enum"]):
            val_upper = raw_val.upper()
            if (
                val_upper.endswith("_UNSPECIFIED")
                or val_upper.endswith("_UNKNOWN")
                or val_upper == "UNSPECIFIED"
                or val_upper == "UNKNOWN"
            ):
                continue

            case_swift_name = to_camel_case(raw_val[len(prefix) :], lower=True)
            raw_case_desc = (
                enum_descriptions[idx]
                if idx < len(enum_descriptions)
                else None
            )
            case_description = (
                format_enum_case_docc(
                    raw_case_desc,
                    in_gl=not track_backends or raw_val in gl_cases,
                    in_ai=not track_backends or raw_val in ai_cases,
                    wrap_width=self.member_wrap_width,
                )
                or None
            )
            case_is_deprecated = (
                enum_deprecated_list[idx]
                if idx < len(enum_deprecated_list)
                else False
            )

            cases.append(
                SwiftEnumCase(
                    swift_name=case_swift_name,
                    raw_value=raw_val,
                    description=case_description,
                    is_deprecated=case_is_deprecated,
                )
            )
        return cases

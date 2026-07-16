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

import argparse
import copy
import json
import os
import sys
import yaml
from jinja2 import Environment, FileSystemLoader

# Swift Keywords
SWIFT_KEYWORDS = {
    "associatedtype", "class", "deinit", "enum", "extension", "fileprivate",
    "func", "import", "init", "inout", "internal", "let", "open", "operator",
    "private", "precedencegroup", "protocol", "public", "rethrows", "static",
    "struct", "subscript", "typealias", "var", "break", "case", "catch",
    "continue", "default", "defer", "do", "else", "fallthrough", "for",
    "guard", "if", "in", "repeat", "return", "throw", "throws", "switch",
    "where", "while", "as", "any", "some", "Any", "self", "Self", "super",
    "nil", "true", "false", "is", "try", "Type"
}

# Configurable constants (loaded dynamically from overrides YAML file if present)
TYPE_OVERRIDES = {}
EXCLUDED_SCHEMAS = set()
MANUAL_OVERRIDE_SCHEMAS = set()
TYPE_DIVERGENCES_RESOLUTIONS = {}
SCHEMA_RENAME_MAPPINGS = {}

EXCLUDED_PROPERTIES = {
    # E.g. "SomeSchema": {"unwanted_field"}
}


class SwiftType:
    def __init__(self, name, namespace, kind, description=None, is_deprecated=False):
        self.name = name          # e.g. "GenerateContentRequest" or "Category"
        self.namespace = namespace # e.g. "GoogleAI" or "GoogleAI.SafetySetting"
        self.kind = kind          # "struct", "class", "enum"
        self.description = description
        self.is_deprecated = is_deprecated
        # For struct / class
        self.properties = []      # list of SwiftProperty
        # For enum
        self.cases = []           # list of SwiftEnumCase
        # For oneOf support
        self.has_oneof = False
        self.oneof_name = None
        self.oneof_properties = []


class SwiftProperty:
    def __init__(self, swift_name, json_name, swift_type, description=None, init_description=None, is_deprecated=False, is_required=False):
        self.swift_name = swift_name
        self.json_name = json_name
        self.swift_type = swift_type
        self.description = description
        self.init_description = init_description
        self.is_deprecated = is_deprecated
        self.is_required = is_required


class SwiftEnumCase:
    def __init__(self, swift_name, raw_value, description=None, is_deprecated=False):
        self.swift_name = swift_name
        self.raw_value = raw_value
        self.description = description
        self.is_deprecated = is_deprecated


def escape_swift_name(name):
    if name in SWIFT_KEYWORDS:
        return f"`{name}`"
    return name


def to_camel_case(s, lower=True):
    if s.isupper():
        s = s.lower()
    if "_" in s:
        parts = s.split("_")
        parts = [p for p in parts if p]
        if not parts:
            return ""
        first = parts[0].lower() if lower else parts[0].capitalize()
        rest = [p.capitalize() for p in parts[1:]]
        result = first + "".join(rest)
    else:
        if not s:
            return ""
        if lower:
            result = s[0].lower() + s[1:] if len(s) > 1 else s.lower()
        else:
            result = s[0].upper() + s[1:] if len(s) > 1 else s.upper()
    return escape_swift_name(result)


def get_primitive_type(prop_data):
    t = prop_data.get("type")
    if isinstance(t, list):
        # Filter out 'null' to get the actual primitive type
        t_non_null = [item for item in t if item != "null"]
        t = t_non_null[0] if t_non_null else None
        
    fmt = prop_data.get("format")
    if t == "string":
        if fmt in ("google-datetime", "date-time"):
            return "String"
        elif fmt == "google-duration":
            return "String"
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


def resolve_ref(ref):
    if ref.startswith("#/components/schemas/"):
        return ref.split("/")[-1]
    return ref


def find_refs_in_json(data):
    refs = set()
    if isinstance(data, dict):
        if "$ref" in data:
            refs.add(resolve_ref(data["$ref"]))
        for v in data.values():
            refs.update(find_refs_in_json(v))
    elif isinstance(data, list):
        for item in data:
            refs.update(find_refs_in_json(item))
    return refs


def find_refs_in_schema(schema_name, data):
    refs = set()
    if not isinstance(data, dict):
        return refs
        
    for k, v in data.items():
        if k == "properties" and isinstance(v, dict):
            for prop_name, prop_data in v.items():
                # Skip manually excluded properties
                if schema_name in EXCLUDED_PROPERTIES and prop_name in EXCLUDED_PROPERTIES[schema_name]:
                    continue
                
                # Skip auto-excluded properties (referencing excluded schemas)
                is_ref_excluded = False
                if "$ref" in prop_data:
                    ref_name = resolve_ref(prop_data["$ref"])
                    if ref_name in EXCLUDED_SCHEMAS:
                        is_ref_excluded = True
                elif prop_data.get("type") == "array" and "items" in prop_data:
                    items_data = prop_data["items"]
                    if "$ref" in items_data:
                        ref_name = resolve_ref(items_data["$ref"])
                        if ref_name in EXCLUDED_SCHEMAS:
                            is_ref_excluded = True
                            
                if is_ref_excluded:
                    continue
                    
                refs.update(find_refs_in_json(prop_data))
        else:
            refs.update(find_refs_in_json(v))
            
    return refs


def resolve_all_types(schemas, roots):
    to_visit = list(roots)
    visited = set()
    resolved_schemas = {}
    
    while to_visit:
        name = to_visit.pop(0)
        if name in visited or name in EXCLUDED_SCHEMAS:
            continue
        visited.add(name)
        
        schema_data = schemas.get(name)
        if not schema_data:
            continue
            
        resolved_schemas[name] = schema_data
        
        # Traverse the schema to find dependencies, skipping excluded properties
        for ref in find_refs_in_schema(name, schema_data):
            if ref not in visited:
                to_visit.append(ref)
                        
    return resolved_schemas


def find_direct_refs(data):
    refs = set()
    if isinstance(data, dict):
        if data.get("type") == "array":
            return set()
        if "additionalProperties" in data:
            return set()
        if "$ref" in data:
            refs.add(resolve_ref(data["$ref"]))
        for k, v in data.items():
            if k not in ("items", "additionalProperties"):
                refs.update(find_direct_refs(v))
    elif isinstance(data, list):
        for item in data:
            refs.update(find_direct_refs(item))
    return refs


def get_direct_references(schema_name, schema_data):
    refs = set()
    if "properties" in schema_data:
        for prop_name, prop_data in schema_data["properties"].items():
            if schema_name in EXCLUDED_PROPERTIES and prop_name in EXCLUDED_PROPERTIES[schema_name]:
                continue
            refs.update(find_direct_refs(prop_data))
    if "oneOf" in schema_data:
        refs.update(find_direct_refs(schema_data["oneOf"]))
    return refs


def build_direct_dependency_graph(resolved_schemas):
    graph = {}
    for name, data in resolved_schemas.items():
        graph[name] = get_direct_references(name, data)
    return graph


def find_cycle_nodes(graph):
    cycle_nodes = set()
    
    def can_reach(start, current, visited):
        for neighbor in graph.get(current, []):
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


def strip_enum_prefix(cases):
    filtered_cases = [
        c for c in cases
        if not (c.endswith("_UNSPECIFIED") or c.endswith("_UNKNOWN") or c == "UNSPECIFIED" or c == "UNKNOWN")
    ]
    if not filtered_cases:
        return "", cases
    
    import os
    prefix = os.path.commonprefix(filtered_cases)
    if prefix and "_" in prefix:
        last_underscore = prefix.rfind("_")
        prefix = prefix[:last_underscore + 1]
    else:
        prefix = ""
    return prefix, filtered_cases


def format_schema_docc(name, data):
    gl_orig = data.get("x-gl-original-name")
    ai_orig = data.get("x-ai-original-name")
    gl_desc = (data.get("x-gl-description") or "").strip()
    ai_desc = (data.get("x-ai-description") or "").strip()
    
    # Remove any old Variant suffixes
    if "\n\nVariant:\n" in gl_desc:
        gl_desc = gl_desc.split("\n\nVariant:\n")[0].strip()
    if "\n\nVariant:\n" in ai_desc:
        ai_desc = ai_desc.split("\n\nVariant:\n")[0].strip()
        
    is_gl_only = gl_orig is not None and ai_orig is None
    is_ai_only = ai_orig is not None and gl_orig is None
    is_both = gl_orig is not None and ai_orig is not None
    
    docc_desc = f"An internal data model for `{name}`."
    
    if is_both:
        docc_desc += f"\n\n### Gemini Developer API\n\nType: `{gl_orig}`"
        if gl_desc:
            docc_desc += f"\n\n{gl_desc}"
        docc_desc += f"\n\n### Gemini Enterprise Agent Platform\n\nType: `{ai_orig}`"
        if ai_desc:
            docc_desc += f"\n\n{ai_desc}"
    elif is_gl_only:
        # Clean any old support notes if present
        if "> Important:" in gl_desc:
            gl_desc = gl_desc.split("\n\n> Important:")[0].strip()
        docc_desc += f"\n\n### Gemini Developer API\n\nType: `{gl_orig}`"
        if gl_desc:
            docc_desc += f"\n\n{gl_desc}"
        docc_desc += "\n\n### Gemini Enterprise Agent Platform\n\n> Important: This type is not supported in the Gemini Enterprise Agent Platform."
    elif is_ai_only:
        # Clean any old support notes if present
        if "> Important:" in ai_desc:
            ai_desc = ai_desc.split("\n\n> Important:")[0].strip()
        docc_desc += "\n\n### Gemini Developer API\n\n> Important: This type is not supported in the Gemini Developer API."
        docc_desc += f"\n\n### Gemini Enterprise Agent Platform\n\nType: `{ai_orig}`"
        if ai_desc:
            docc_desc += f"\n\n{ai_desc}"
    else:
        raw_desc = (data.get("description") or "").strip()
        if "\n\nVariant:\n" in raw_desc:
            raw_desc = raw_desc.split("\n\nVariant:\n")[0].strip()
        if raw_desc:
            docc_desc = raw_desc
            
    return docc_desc


def format_property_docc(prop_name, prop_data):
    gl_desc = (prop_data.get("x-gl-description") or "").strip()
    ai_desc = (prop_data.get("x-ai-description") or "").strip()
    
    if "\n\nVariant:\n" in gl_desc:
        gl_desc = gl_desc.split("\n\nVariant:\n")[0].strip()
    if "\n\nVariant:\n" in ai_desc:
        ai_desc = ai_desc.split("\n\nVariant:\n")[0].strip()
        
    has_gl = "x-gl-description" in prop_data
    has_ai = "x-ai-description" in prop_data
    
    # Fallback if no backend metadata is available
    if not has_gl and not has_ai:
        raw_desc = (prop_data.get("description") or "").strip()
        if "\n\nVariant:\n" in raw_desc:
            raw_desc = raw_desc.split("\n\nVariant:\n")[0].strip()
        return raw_desc
        
    # Helper to get the first non-empty line of description
    def get_first_line(desc):
        if not desc:
            return ""
        lines = [line.strip() for line in desc.split("\n") if line.strip()]
        if lines:
            return lines[0]
        return ""
        
    summary_line = get_first_line(gl_desc or ai_desc)
    
    if has_gl and has_ai:
        if gl_desc and ai_desc and gl_desc != ai_desc:
            docc = ""
            if summary_line:
                docc += f"{summary_line}\n\n"
            docc += f"### Gemini Developer API\n\n{gl_desc}\n\n### Gemini Enterprise Agent Platform\n\n{ai_desc}"
            return docc
        else:
            desc = gl_desc or ai_desc or ""
            if "\n\nVariant:\n" in desc:
                desc = desc.split("\n\nVariant:\n")[0].strip()
            return desc
    elif has_gl:
        # Only available in Developer API
        if "> Important:" in gl_desc:
            gl_desc = gl_desc.split("\n\n> Important:")[0].strip()
        
        docc = ""
        if summary_line:
            docc += f"{summary_line}\n\n"
        docc += "### Gemini Developer API"
        if gl_desc:
            docc += f"\n\n{gl_desc}"
        docc += "\n\n### Gemini Enterprise Agent Platform\n\n> Important: This property is not supported in the Gemini Enterprise Agent Platform."
        return docc
    else:
        # Only available in Enterprise Agent Platform
        if "> Important:" in ai_desc:
            ai_desc = ai_desc.split("\n\n> Important:")[0].strip()
            
        docc = ""
        if summary_line:
            docc += f"{summary_line}\n\n"
        docc += "### Gemini Developer API\n\n> Important: This property is not supported in the Gemini Developer API."
        docc += "\n\n### Gemini Enterprise Agent Platform"
        if ai_desc:
            docc += f"\n\n{ai_desc}"
        return docc


def process_resolved_schemas(resolved_schemas, cycle_nodes, namespace):
    swift_types = []
    
    def process_schema(name, data, namespace):
        is_class = name in cycle_nodes
        
        # Resolve dotted nesting names (e.g. Part.MediaResolution)
        actual_name = name
        actual_namespace = namespace
        if "." in name:
            name_parts = name.split(".")
            actual_name = name_parts[-1]
            actual_namespace = f"{namespace}." + ".".join(name_parts[:-1])
            
        # Check if the schema itself is an Enum (standalone top-level enum)
        if "enum" in data:
            enum_deprecated_list = data.get("enumDeprecated", data.get("x-google-enum-deprecated", []))
            enum_descriptions = data.get("enumDescriptions", data.get("x-google-enum-descriptions", []))
            
            cases = []
            prefix, filtered_raw_cases = strip_enum_prefix(data["enum"])
            
            for idx, raw_val in enumerate(data["enum"]):
                val_upper = raw_val.upper()
                if val_upper.endswith("_UNSPECIFIED") or val_upper.endswith("_UNKNOWN") or val_upper == "UNSPECIFIED" or val_upper == "UNKNOWN":
                    continue
                
                case_swift_name = to_camel_case(raw_val[len(prefix):], lower=True)
                case_description = enum_descriptions[idx] if idx < len(enum_descriptions) else None
                case_is_deprecated = enum_deprecated_list[idx] if idx < len(enum_deprecated_list) else False
                
                cases.append(SwiftEnumCase(
                    swift_name=case_swift_name,
                    raw_value=raw_val,
                    description=case_description,
                    is_deprecated=case_is_deprecated
                ))
                
            enum_st = SwiftType(
                name=actual_name,
                namespace=actual_namespace,
                kind="enum",
                description=format_schema_docc(name, data),
                is_deprecated=data.get("deprecated", False)
            )
            enum_st.cases = cases
            swift_types.append(enum_st)
            return

        st = SwiftType(
            name=actual_name,
            namespace=actual_namespace,
            kind="class" if is_class else "struct",
            description=format_schema_docc(name, data),
            is_deprecated=data.get("deprecated", False)
        )
        
        # Extract flat oneOf properties
        oneof_options = data.get("oneOf", [])
        oneof_keys = set()
        if oneof_options:
            for option in oneof_options:
                if "required" in option and isinstance(option["required"], list):
                    oneof_keys.update(option["required"])
        
        if oneof_keys:
            st.has_oneof = True
            st.oneof_name = f"{actual_name}Data"
            
        properties = data.get("properties", {})
        required_props = data.get("required", [])
        for prop_name, prop_data in properties.items():
            if name in EXCLUDED_PROPERTIES and prop_name in EXCLUDED_PROPERTIES[name]:
                continue
                
            # Check if property references an excluded schema
            is_ref_excluded = False
            if "$ref" in prop_data:
                ref_name = resolve_ref(prop_data["$ref"])
                if ref_name in EXCLUDED_SCHEMAS:
                    is_ref_excluded = True
            elif prop_data.get("type") == "array" and "items" in prop_data:
                items_data = prop_data["items"]
                if "$ref" in items_data:
                    ref_name = resolve_ref(items_data["$ref"])
                    if ref_name in EXCLUDED_SCHEMAS:
                        is_ref_excluded = True
                        
            if is_ref_excluded:
                continue
                
            swift_prop_name = to_camel_case(prop_name, lower=True)
            
            # Inline Enum
            if "enum" in prop_data:
                enum_name = to_camel_case(prop_name, lower=False)
                enum_namespace = f"{actual_namespace}.{actual_name}"
                
                enum_deprecated_list = prop_data.get("enumDeprecated", prop_data.get("x-google-enum-deprecated", []))
                enum_descriptions = prop_data.get("enumDescriptions", prop_data.get("x-google-enum-descriptions", []))
                
                cases = []
                prefix, filtered_raw_cases = strip_enum_prefix(prop_data["enum"])
                
                for idx, raw_val in enumerate(prop_data["enum"]):
                    val_upper = raw_val.upper()
                    if val_upper.endswith("_UNSPECIFIED") or val_upper.endswith("_UNKNOWN") or val_upper == "UNSPECIFIED" or val_upper == "UNKNOWN":
                        continue
                    
                    case_swift_name = to_camel_case(raw_val[len(prefix):], lower=True)
                    case_description = enum_descriptions[idx] if idx < len(enum_descriptions) else None
                    case_is_deprecated = enum_deprecated_list[idx] if idx < len(enum_deprecated_list) else False
                    
                    cases.append(SwiftEnumCase(
                        swift_name=case_swift_name,
                        raw_value=raw_val,
                        description=case_description,
                        is_deprecated=case_is_deprecated
                     ))
                
                enum_st = SwiftType(
                    name=enum_name,
                    namespace=enum_namespace,
                    kind="enum",
                    description=format_property_docc(prop_name, prop_data),
                    is_deprecated=prop_data.get("deprecated", False)
                )
                enum_st.cases = cases
                swift_types.append(enum_st)
                
                swift_type_str = enum_name
                
            # Inline Object (Nested Struct)
            elif prop_data.get("type") == "object" and "properties" in prop_data:
                nested_name = to_camel_case(prop_name, lower=False)
                nested_namespace = f"{actual_namespace}.{actual_name}"
                
                process_schema(nested_name, prop_data, nested_namespace)
                swift_type_str = nested_name
                
            else:
                swift_type_str = resolve_swift_type_string(prop_name, prop_data, actual_name, actual_namespace)
                
            is_prop_deprecated = prop_data.get("deprecated", False)
            if not is_prop_deprecated:
                if "$ref" in prop_data:
                    ref_name = resolve_ref(prop_data["$ref"])
                    if ref_name in resolved_schemas and resolved_schemas[ref_name].get("deprecated", False):
                        is_prop_deprecated = True
                elif prop_data.get("type") == "array" and "items" in prop_data:
                    items_data = prop_data["items"]
                    if "$ref" in items_data:
                        ref_name = resolve_ref(items_data["$ref"])
                        if ref_name in resolved_schemas and resolved_schemas[ref_name].get("deprecated", False):
                            is_prop_deprecated = True
                
            # Generate init_description
            gl_p_desc = (prop_data.get("x-gl-description") or "").strip()
            ai_p_desc = (prop_data.get("x-ai-description") or "").strip()
            if "\n\nVariant:\n" in gl_p_desc:
                gl_p_desc = gl_p_desc.split("\n\nVariant:\n")[0].strip()
            if "\n\nVariant:\n" in ai_p_desc:
                ai_p_desc = ai_p_desc.split("\n\nVariant:\n")[0].strip()
                
            has_gl = "x-gl-description" in prop_data
            has_ai = "x-ai-description" in prop_data
            
            def get_first_line(desc):
                if not desc:
                    return ""
                lines = [line.strip() for line in desc.split("\n") if line.strip()]
                if lines:
                    return lines[0]
                return ""
                
            p_desc = gl_p_desc or ai_p_desc
            if not p_desc:
                p_desc = (prop_data.get("description") or "").strip()
                if "\n\nVariant:\n" in p_desc:
                    p_desc = p_desc.split("\n\nVariant:\n")[0].strip()
                    
            first_line = get_first_line(p_desc)
            is_backend_specific = (has_gl != has_ai) or (gl_p_desc and ai_p_desc and gl_p_desc != ai_p_desc)
            
            if is_backend_specific:
                if has_gl and not has_ai:
                    suffix = " (Gemini Developer API only)"
                elif has_ai and not has_gl:
                    suffix = " (Gemini Enterprise Agent Platform only)"
                else:
                    suffix = " (behavior varies by backend)"
                init_desc = f"{first_line}{suffix}. For more details, see ``{swift_prop_name}``."
            else:
                init_desc = first_line
                
            if not init_desc:
                init_desc = f"For more details, see ``{swift_prop_name}``."
                
            prop = SwiftProperty(
                swift_name=swift_prop_name,
                json_name=prop_name,
                swift_type=swift_type_str,
                description=format_property_docc(prop_name, prop_data),
                init_description=init_desc,
                is_deprecated=is_prop_deprecated,
                is_required=prop_name in required_props
            )
            
            if prop_name in oneof_keys:
                st.oneof_properties.append(prop)
            else:
                st.properties.append(prop)
            
        swift_types.append(st)
        
    def resolve_swift_type_string(prop_name, prop_data, parent_name, namespace):
        prim = get_primitive_type(prop_data)
        if prim:
            return prim
            
        if "$ref" in prop_data:
            ref = resolve_ref(prop_data["$ref"])
            return TYPE_OVERRIDES.get(ref, ref)
            
        if prop_data.get("type") == "array":
            items_data = prop_data.get("items", {})
            item_type = resolve_swift_type_string(prop_name, items_data, parent_name, namespace)
            return f"[{item_type}]"
            
        if prop_data.get("type") == "object":
            add_props = prop_data.get("additionalProperties", {})
            val_type = resolve_swift_type_string(prop_name, add_props, parent_name, namespace)
            return f"[String: {val_type}]"
            
        return "JSONValue"
        
    for name, data in resolved_schemas.items():
        process_schema(name, data, namespace)
        
    return swift_types


def strip_prefix_from_schemas(schemas, prefix):
    if not prefix:
        return schemas
        
    def strip_prefix_from_value(val):
        if isinstance(val, dict):
            new_dict = {}
            for k, v in val.items():
                if k == "$ref" and isinstance(v, str):
                    if v.startswith("#/components/schemas/"):
                        ref_name = v.split("/")[-1]
                        if ref_name.startswith(prefix):
                            ref_name = ref_name[len(prefix):]
                        new_dict[k] = f"#/components/schemas/{ref_name}"
                    elif v.startswith(prefix):
                        new_dict[k] = v[len(prefix):]
                    else:
                        new_dict[k] = v
                else:
                    new_dict[k] = strip_prefix_from_value(v)
            return new_dict
        elif isinstance(val, list):
            return [strip_prefix_from_value(item) for item in val]
        return val

    new_schemas = {}
    is_gl = prefix.startswith("GoogleAi")
    
    def annotate_properties(schema_dict):
        if isinstance(schema_dict, dict) and "properties" in schema_dict:
            props = schema_dict["properties"]
            if isinstance(props, dict):
                for p_name, p_data in props.items():
                    if isinstance(p_data, dict):
                        if is_gl:
                            p_data["x-gl-description"] = p_data.get("description", "")
                        else:
                            p_data["x-ai-description"] = p_data.get("description", "")

    # First, populate un-prefixed schemas
    for schema_name, schema_data in schemas.items():
        if not schema_name.startswith(prefix):
            stripped = strip_prefix_from_value(schema_data)
            if isinstance(stripped, dict):
                annotate_properties(stripped)
                if is_gl:
                    stripped["x-gl-original-name"] = schema_name
                    stripped["x-gl-description"] = schema_data.get("description", "")
                else:
                    stripped["x-ai-original-name"] = schema_name
                    stripped["x-ai-description"] = schema_data.get("description", "")
            new_schemas[schema_name] = stripped
            
    # Then, merge or add prefixed schemas
    for schema_name, schema_data in schemas.items():
        if schema_name.startswith(prefix):
            new_name = schema_name[len(prefix):]
            stripped_data = strip_prefix_from_value(schema_data)
            if isinstance(stripped_data, dict):
                annotate_properties(stripped_data)
                if is_gl:
                    stripped_data["x-gl-original-name"] = schema_name
                    stripped_data["x-gl-description"] = schema_data.get("description", "")
                else:
                    stripped_data["x-ai-original-name"] = schema_name
                    stripped_data["x-ai-description"] = schema_data.get("description", "")
            if new_name in new_schemas:
                new_schemas[new_name] = merge_schemas(new_name, new_schemas[new_name], stripped_data)
            else:
                new_schemas[new_name] = stripped_data
            if "id" in new_schemas[new_name] and isinstance(new_schemas[new_name]["id"], str) and new_schemas[new_name]["id"].startswith(prefix):
                new_schemas[new_name]["id"] = new_schemas[new_name]["id"][len(prefix):]
            
    return new_schemas


def rename_schemas_and_refs(schemas, mappings):
    if not mappings:
        return schemas
        
    def rename_refs_in_value(val):
        if isinstance(val, dict):
            new_dict = {}
            for k, v in val.items():
                if k == "$ref" and isinstance(v, str):
                    if v.startswith("#/components/schemas/"):
                        ref_name = v.split("/")[-1]
                        if ref_name in mappings:
                            ref_name = mappings[ref_name]
                        new_dict[k] = f"#/components/schemas/{ref_name}"
                    elif v in mappings:
                        new_dict[k] = mappings[v]
                    else:
                        new_dict[k] = v
                else:
                    new_dict[k] = rename_refs_in_value(v)
            return new_dict
        elif isinstance(val, list):
            return [rename_refs_in_value(item) for item in val]
        return val

    new_schemas = {}
    for schema_name, schema_data in schemas.items():
        new_name = mappings.get(schema_name, schema_name)
        new_schemas[new_name] = rename_refs_in_value(schema_data)
        if "id" in new_schemas[new_name] and isinstance(new_schemas[new_name]["id"], str):
            curr_id = new_schemas[new_name]["id"]
            new_schemas[new_name]["id"] = mappings.get(curr_id, curr_id)
            
    return new_schemas


def write_types(swift_types, output_dir, templates_dir, access_level, root_namespace, verbose=False):
    env = Environment(loader=FileSystemLoader(templates_dir))
    
    struct_tmpl = env.get_template("struct.swift.jinja")
    class_tmpl = env.get_template("class.swift.jinja")
    enum_tmpl = env.get_template("enum.swift.jinja")
    
    os.makedirs(output_dir, exist_ok=True)
    written_files = []
    
    for st in swift_types:
        parts = st.namespace.split(".")
        if parts and parts[0] == root_namespace:
            parts = parts[1:]
        
        filename_parts = parts + [st.name.replace("`", "")]
        filename = "+".join(filename_parts) + ".swift"
        file_path = os.path.join(output_dir, filename)
        
        all_props = st.properties + st.oneof_properties
        
        if st.kind == "struct":
            rendered = struct_tmpl.render(
                namespace=st.namespace,
                name=st.name,
                description=st.description,
                is_deprecated=st.is_deprecated,
                properties=st.properties,
                has_oneof=st.has_oneof,
                oneof_name=st.oneof_name,
                oneof_properties=st.oneof_properties,
                uses_foundation_types=any("Date" in p.swift_type for p in all_props),
                uses_shared_data_models=st.has_oneof or any("JSONValue" in p.swift_type or "APIError" in p.swift_type for p in all_props),
                access_level=access_level
            )
        elif st.kind == "class":
            rendered = class_tmpl.render(
                namespace=st.namespace,
                name=st.name,
                description=st.description,
                is_deprecated=st.is_deprecated,
                properties=st.properties,
                has_oneof=st.has_oneof,
                oneof_name=st.oneof_name,
                oneof_properties=st.oneof_properties,
                uses_foundation_types=any("Date" in p.swift_type for p in all_props),
                uses_shared_data_models=st.has_oneof or any("JSONValue" in p.swift_type or "APIError" in p.swift_type for p in all_props),
                access_level=access_level
            )
        elif st.kind == "enum":
            rendered = enum_tmpl.render(
                namespace=st.namespace,
                name=st.name,
                description=st.description,
                is_deprecated=st.is_deprecated,
                cases=st.cases,
                access_level=access_level
            )
        else:
            continue
            
        with open(file_path, "w") as f:
            f.write(rendered)
            
        written_files.append(file_path)
        if verbose:
            print(f"Generated type: {filename}")
        
    # Clean up old generated files
    for existing in os.listdir(output_dir):
        if existing.endswith(".swift") and existing not in (f"{root_namespace}.swift", "ResponseFormatConfig.swift"):
            full_path = os.path.join(output_dir, existing)
            if full_path not in written_files:
                os.remove(full_path)
                if verbose:
                    print(f"Removed old generated file: {existing}")
                
    return written_files


def merge_properties(parent_name, prop_name, prop1, prop2):
    # Check override registry
    if parent_name in TYPE_DIVERGENCES_RESOLUTIONS and prop_name in TYPE_DIVERGENCES_RESOLUTIONS[parent_name]:
        override = TYPE_DIVERGENCES_RESOLUTIONS[parent_name][prop_name]
        merged = dict(prop1)
        merged.update(override)
        # Merge descriptions
        desc1 = prop1.get("description", "")
        desc2 = prop2.get("description", "")
        if desc1 and desc2 and desc1 != desc2:
            merged["description"] = f"{desc1}\n\nVariant:\n{desc2}"
        elif desc2:
            merged["description"] = desc2
        print(f"Info: Applied registry resolution override for property '{prop_name}' in '{parent_name}' -> {override}")
        return merged

    if prop1 == prop2:
        return prop1
        
    merged = dict(prop1)
    
    # Propagate original names and descriptions
    if "x-gl-original-name" in prop1:
        merged["x-gl-original-name"] = prop1["x-gl-original-name"]
    elif "x-gl-original-name" in prop2:
        merged["x-gl-original-name"] = prop2["x-gl-original-name"]

    if "x-ai-original-name" in prop2:
        merged["x-ai-original-name"] = prop2["x-ai-original-name"]
    elif "x-ai-original-name" in prop1:
        merged["x-ai-original-name"] = prop1["x-ai-original-name"]

    merged["x-gl-description"] = prop1.get("x-gl-description") or prop1.get("description", "")
    merged["x-ai-description"] = prop2.get("x-ai-description") or prop2.get("description", "")
    
    # Merge descriptions
    desc1 = prop1.get("description", "")
    desc2 = prop2.get("description", "")
    if desc1 and desc2 and desc1 != desc2:
        merged["description"] = f"{desc1}\n\nVariant:\n{desc2}"
    elif desc2:
        merged["description"] = desc2
        
    # Check types
    t1 = prop1.get("type")
    t2 = prop2.get("type")
    
    if t1 != t2:
        # Resolve type conflicts (e.g. integer vs number)
        numeric_types = {"integer", "number"}
        if t1 in numeric_types and t2 in numeric_types:
            print(f"Warning: Promoting numeric types for property '{prop_name}' in schema '{parent_name}': {t1} vs {t2}")
            merged["type"] = "number"
            if "format" in merged:
                merged.pop("format")
        else:
            print(f"Warning: Type conflict for property '{prop_name}' in schema '{parent_name}': {t1} vs {t2}")
            
    # Resolve format conflicts if types are the same
    f1 = prop1.get("format")
    f2 = prop2.get("format")
    if f1 != f2:
        if f1 and f2:
            if "format" in merged:
                merged.pop("format")
                
    # If they are refs, check if they are different refs
    ref1 = prop1.get("$ref")
    ref2 = prop2.get("$ref")
    if ref1 != ref2:
        print(f"Warning: Ref conflict for property '{prop_name}' in schema '{parent_name}': {ref1} vs {ref2}")
        
    # If they are arrays, merge their item schemas
    if t1 == "array" and t2 == "array" and "items" in prop1 and "items" in prop2:
        merged["items"] = merge_properties(parent_name, f"{prop_name}.items", prop1["items"], prop2["items"])
        
    # If they are objects with properties, merge properties recursively
    if t1 == "object" and t2 == "object" and "properties" in prop1 and "properties" in prop2:
        merged_sub_props = {}
        sub_props1 = prop1.get("properties", {})
        sub_props2 = prop2.get("properties", {})
        
        all_sub_names = []
        seen_sub = set()
        for sub_name in list(sub_props1.keys()) + list(sub_props2.keys()):
            if sub_name not in seen_sub:
                seen_sub.add(sub_name)
                all_sub_names.append(sub_name)
                
        for sub_name in all_sub_names:
            if sub_name in sub_props1 and sub_name in sub_props2:
                merged_sub_props[sub_name] = merge_properties(parent_name, f"{prop_name}.{sub_name}", sub_props1[sub_name], sub_props2[sub_name])
            elif sub_name in sub_props1:
                merged_sub_props[sub_name] = sub_props1[sub_name]
            else:
                merged_sub_props[sub_name] = sub_props2[sub_name]
        merged["properties"] = merged_sub_props
        
    return merged


def merge_schemas(name, schema1, schema2):
    if schema1.get("type") != "object" or schema2.get("type") != "object":
        return schema1
        
    merged = dict(schema1)
    
    # Propagate original names and descriptions
    if "x-gl-original-name" in schema1:
        merged["x-gl-original-name"] = schema1["x-gl-original-name"]
    elif "x-gl-original-name" in schema2:
        merged["x-gl-original-name"] = schema2["x-gl-original-name"]

    if "x-ai-original-name" in schema2:
        merged["x-ai-original-name"] = schema2["x-ai-original-name"]
    elif "x-ai-original-name" in schema1:
        merged["x-ai-original-name"] = schema1["x-ai-original-name"]

    merged["x-gl-description"] = schema1.get("x-gl-description") or schema1.get("description", "")
    merged["x-ai-description"] = schema2.get("x-ai-description") or schema2.get("description", "")
    
    # Merge descriptions
    desc1 = schema1.get("description", "")
    desc2 = schema2.get("description", "")
    if desc1 and desc2 and desc1 != desc2:
        merged["description"] = f"{desc1}\n\nVariant:\n{desc2}"
    elif desc2:
        merged["description"] = desc2
        
    # Merge properties
    props1 = schema1.get("properties", {})
    props2 = schema2.get("properties", {})
    
    all_prop_names = []
    seen_prop = set()
    for prop_name in list(props1.keys()) + list(props2.keys()):
        if prop_name not in seen_prop:
            seen_prop.add(prop_name)
            all_prop_names.append(prop_name)
            
    merged_props = {}
    
    for prop_name in all_prop_names:
        if prop_name in props1 and prop_name in props2:
            merged_props[prop_name] = merge_properties(name, prop_name, props1[prop_name], props2[prop_name])
        elif prop_name in props1:
            merged_props[prop_name] = props1[prop_name]
        else:
            merged_props[prop_name] = props2[prop_name]
            
    merged["properties"] = merged_props
    return merged


def main():
    parser = argparse.ArgumentParser(description="Generate Swift types from one or more OpenAPI Specifications.")
    parser.add_argument("--openapi-spec", default="utilities/discovery_documents/firebasevertexai-openapi.yaml",
                        help="Path to the OpenAPI specification YAML file.")
    parser.add_argument("--templates-dir", default="utilities/templates",
                        help="Directory containing the Jinja templates.")
    parser.add_argument("--output-dir", default="Sources/InternalGeminiDataModels",
                        help="Target output directory for the Swift source files.")
    parser.add_argument("--roots", nargs="+", default=[
                            "GenerateContentRequest",
                            "GenerateContentResponse",
                            "TemplateGenerateContentRequest",
                            "CountTokensRequest",
                            "CountTokensResponse"
                        ],
                        help="Root schema names to resolve transitively.")
    parser.add_argument("--access-level", default="package",
                        help="Access level keyword for generated types (e.g. public, package, internal).")
    parser.add_argument("--strip-prefix", nargs="*", default=[
                            "GoogleAiGenerativelanguageV1beta",
                            "GoogleCloudAiplatformV1beta1"
                        ],
                        help="Prefixes to strip from schema IDs and reference names for each document.")
    parser.add_argument("--namespace", default="GeminiDataModels",
                        help="Root Swift namespace for the generated types.")
    parser.add_argument("--overrides-file", default="utilities/discovery_documents/firebasevertexai-overrides.yaml",
                        help="Path to the overrides YAML file containing generatorConfig.")
    parser.add_argument("--verbose", action="store_true",
                        help="Print detailed generation progress (e.g. list of generated files).")
    args = parser.parse_args()
    
    global TYPE_OVERRIDES, EXCLUDED_SCHEMAS, MANUAL_OVERRIDE_SCHEMAS, SCHEMA_RENAME_MAPPINGS, EXCLUDED_PROPERTIES
    if os.path.exists(args.overrides_file):
        with open(args.overrides_file, "r") as f:
            overrides = yaml.safe_load(f) or {}
            gen_config = overrides.get("generatorConfig", {})
            TYPE_OVERRIDES = gen_config.get("typeOverrides", {})
            EXCLUDED_SCHEMAS = set(gen_config.get("excludedSchemas", []))
            MANUAL_OVERRIDE_SCHEMAS = set(gen_config.get("manualOverrideSchemas", []))
            SCHEMA_RENAME_MAPPINGS = gen_config.get("renameMappings", {})
            EXCLUDED_PROPERTIES = gen_config.get("excludedProperties", {})
            print(f"Loaded generator configuration from {args.overrides_file}")
    
    resolved_by_doc = []
    
    if not os.path.exists(args.openapi_spec):
        print(f"Error: Specification file not found at {args.openapi_spec}")
        sys.exit(1)
        
    with open(args.openapi_spec, "r") as f:
        doc = yaml.safe_load(f)
        
    base_schemas = doc.get("components", {}).get("schemas", {})
    print(f"Loaded specification {args.openapi_spec} with {len(base_schemas)} schemas.")
    
    prefixes = args.strip_prefix if args.strip_prefix else [""]
    for prefix in prefixes:
        # Deep copy base schemas to prevent side-effects across prefix-stripping runs
        doc_schemas = copy.deepcopy(base_schemas)
        if prefix:
            doc_schemas = strip_prefix_from_schemas(doc_schemas, prefix)
            print(f"Stripped prefix '{prefix}'. Remaining schema count: {len(doc_schemas)}")
            
        # Rename/align schemas to match across backends
        doc_schemas = rename_schemas_and_refs(doc_schemas, SCHEMA_RENAME_MAPPINGS)
            
        # Resolve transitively for this document
        doc_resolved = resolve_all_types(doc_schemas, args.roots)
        print(f"Resolved {len(doc_resolved)} schemas for prefix '{prefix}' from roots {args.roots}.")
        resolved_by_doc.append(doc_resolved)
        
    # Merge resolved schemas from all documents
    resolved = {}
    for doc_resolved in resolved_by_doc:
        for name, data in doc_resolved.items():
            if name in resolved:
                resolved[name] = merge_schemas(name, resolved[name], data)
            else:
                resolved[name] = data
                
    # Remove manually overridden schemas so they are not generated
    for name in list(resolved.keys()):
        if name in MANUAL_OVERRIDE_SCHEMAS:
            del resolved[name]
                

    print(f"Total merged and resolved schemas: {len(resolved)} from roots {args.roots}.")
    
    # Build Dependency Graph & Detect Cycles
    graph = build_direct_dependency_graph(resolved)
    cycle_nodes = find_cycle_nodes(graph)
    if cycle_nodes:
        print(f"Detected self-referential cycle types (generating as classes): {list(cycle_nodes)}")
        
    # Process types
    swift_types = process_resolved_schemas(resolved, cycle_nodes, args.namespace)
    print(f"Processing generated {len(swift_types)} distinct types (including nested enums/structs).")
    
    # Write types
    write_types(swift_types, args.output_dir, args.templates_dir, args.access_level, args.namespace, verbose=args.verbose)
    print("Code generation completed successfully.")


if __name__ == "__main__":
    main()

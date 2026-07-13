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
import json
import os
import sys
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

# Type Overrides for missing Discovery Doc types
TYPE_OVERRIDES = {
    "MediaResolution": "GenerationConfig.MediaResolution"
}

# Configurable Blocklists
EXCLUDED_SCHEMAS = {
    # Add any schema names to skip entirely
}

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


class SwiftProperty:
    def __init__(self, swift_name, json_name, swift_type, description=None, is_deprecated=False):
        self.swift_name = swift_name
        self.json_name = json_name
        self.swift_type = swift_type
        self.description = description
        self.is_deprecated = is_deprecated


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
    fmt = prop_data.get("format")
    if t == "string":
        if fmt in ("google-datetime", "date-time"):
            return "Date"
        elif fmt == "google-duration":
            return "Duration"
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


def find_refs_in_json(data):
    refs = set()
    if isinstance(data, dict):
        if "$ref" in data:
            refs.add(data["$ref"])
        for v in data.values():
            refs.update(find_refs_in_json(v))
    elif isinstance(data, list):
        for item in data:
            refs.update(find_refs_in_json(item))
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
        
        # Traverse properties to find dependencies
        if "properties" in schema_data:
            for prop_name, prop_data in schema_data["properties"].items():
                if name in EXCLUDED_PROPERTIES and prop_name in EXCLUDED_PROPERTIES[name]:
                    continue
                for ref in find_refs_in_json(prop_data):
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
            refs.add(data["$ref"])
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


def process_resolved_schemas(resolved_schemas, cycle_nodes):
    swift_types = []
    
    def process_schema(name, data, namespace):
        is_class = name in cycle_nodes
        
        st = SwiftType(
            name=name,
            namespace=namespace,
            kind="class" if is_class else "struct",
            description=data.get("description"),
            is_deprecated=data.get("deprecated", False)
        )
        
        properties = data.get("properties", {})
        for prop_name, prop_data in sorted(properties.items()):
            if name in EXCLUDED_PROPERTIES and prop_name in EXCLUDED_PROPERTIES[name]:
                continue
                
            swift_prop_name = to_camel_case(prop_name, lower=True)
            
            # Inline Enum
            if "enum" in prop_data:
                enum_name = to_camel_case(prop_name, lower=False)
                enum_namespace = f"{namespace}.{name}"
                
                enum_deprecated_list = prop_data.get("enumDeprecated", [])
                enum_descriptions = prop_data.get("enumDescriptions", [])
                
                cases = []
                prefix, filtered_raw_cases = strip_enum_prefix(prop_data["enum"])
                
                for idx, raw_val in enumerate(prop_data["enum"]):
                    if raw_val.endswith("_UNSPECIFIED") or raw_val.endswith("_UNKNOWN") or raw_val == "UNSPECIFIED" or raw_val == "UNKNOWN":
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
                    description=prop_data.get("description"),
                    is_deprecated=prop_data.get("deprecated", False)
                )
                enum_st.cases = cases
                swift_types.append(enum_st)
                
                swift_type_str = enum_name
                
            # Inline Object (Nested Struct)
            elif prop_data.get("type") == "object" and "properties" in prop_data:
                nested_name = to_camel_case(prop_name, lower=False)
                nested_namespace = f"{namespace}.{name}"
                
                process_schema(nested_name, prop_data, nested_namespace)
                swift_type_str = nested_name
                
            else:
                swift_type_str = resolve_swift_type_string(prop_name, prop_data, name, namespace)
                
            st.properties.append(SwiftProperty(
                swift_name=swift_prop_name,
                json_name=prop_name,
                swift_type=swift_type_str,
                description=prop_data.get("description"),
                is_deprecated=prop_data.get("deprecated", False)
            ))
            
        swift_types.append(st)
        
    def resolve_swift_type_string(prop_name, prop_data, parent_name, namespace):
        prim = get_primitive_type(prop_data)
        if prim:
            return prim
            
        if "$ref" in prop_data:
            ref = prop_data["$ref"]
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
        process_schema(name, data, "GoogleAI")
        
    return swift_types


def write_types(swift_types, output_dir, templates_dir, access_level):
    env = Environment(loader=FileSystemLoader(templates_dir))
    
    struct_tmpl = env.get_template("struct.swift.jinja")
    class_tmpl = env.get_template("class.swift.jinja")
    enum_tmpl = env.get_template("enum.swift.jinja")
    
    os.makedirs(output_dir, exist_ok=True)
    written_files = []
    
    for st in swift_types:
        parts = st.namespace.split(".")
        if parts and parts[0] == "GoogleAI":
            parts = parts[1:]
        
        filename_parts = parts + [st.name.replace("`", "")]
        filename = "+".join(filename_parts) + ".swift"
        file_path = os.path.join(output_dir, filename)
        
        if st.kind == "struct":
            rendered = struct_tmpl.render(
                namespace=st.namespace,
                name=st.name,
                description=st.description,
                is_deprecated=st.is_deprecated,
                properties=st.properties,
                uses_foundation_types=any("Date" in p.swift_type for p in st.properties),
                access_level=access_level
            )
        elif st.kind == "class":
            rendered = class_tmpl.render(
                namespace=st.namespace,
                name=st.name,
                description=st.description,
                is_deprecated=st.is_deprecated,
                properties=st.properties,
                uses_foundation_types=any("Date" in p.swift_type for p in st.properties),
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
        print(f"Generated type: {filename}")
        
    # Clean up old generated files
    for existing in os.listdir(output_dir):
        if existing.endswith(".swift") and existing != "GoogleAI.swift":
            full_path = os.path.join(output_dir, existing)
            if full_path not in written_files:
                os.remove(full_path)
                print(f"Removed old generated file: {existing}")
                
    return written_files


def main():
    parser = argparse.ArgumentParser(description="Generate Swift types from a Google Discovery Document.")
    parser.add_argument("--discovery-doc", default="utilities/discovery_documents/generativelanguage-discovery.json",
                        help="Path to the Google Discovery Document JSON file.")
    parser.add_argument("--templates-dir", default="utilities/templates",
                        help="Directory containing the Jinja templates.")
    parser.add_argument("--output-dir", default="Sources/GeminiAPIClient/DataModels/GoogleAI",
                        help="Target output directory for the Swift source files.")
    parser.add_argument("--roots", nargs="+", default=["GenerateContentRequest", "GenerateContentResponse"],
                        help="Root schema names to resolve transitively.")
    parser.add_argument("--access-level", default="public",
                        help="Access level keyword for generated types (e.g. public, package, internal).")
    args = parser.parse_args()
    
    if not os.path.exists(args.discovery_doc):
        print(f"Error: Discovery document not found at {args.discovery_doc}")
        sys.exit(1)
        
    with open(args.discovery_doc, "r") as f:
        doc = json.load(f)
        
    schemas = doc.get("schemas", {})
    print(f"Loaded discovery document with {len(schemas)} schemas.")
    
    # Resolve Transitively
    resolved = resolve_all_types(schemas, args.roots)
    print(f"Resolved {len(resolved)} schemas from roots {args.roots}.")
    
    # Build Dependency Graph & Detect Cycles
    graph = build_direct_dependency_graph(resolved)
    cycle_nodes = find_cycle_nodes(graph)
    if cycle_nodes:
        print(f"Detected self-referential cycle types (generating as classes): {list(cycle_nodes)}")
        
    # Process types
    swift_types = process_resolved_schemas(resolved, cycle_nodes)
    print(f"Processing generated {len(swift_types)} distinct types (including nested enums/structs).")
    
    # Write types
    write_types(swift_types, args.output_dir, args.templates_dir, args.access_level)
    print("Code generation completed successfully.")


if __name__ == "__main__":
    main()

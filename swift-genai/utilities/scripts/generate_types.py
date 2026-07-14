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

MANUAL_OVERRIDE_SCHEMAS = {
    # Add schema names to skip generating (e.g. manually implemented)
}

# Explicit resolution for type/format conflicts between schemas
TYPE_DIVERGENCES_RESOLUTIONS = {
    "GenerationConfig": {
        "topK": {
            "type": "integer",
            "format": "int32"
        },
        "responseFormat": {
            "$ref": "ResponseFormatConfig"
        }
    }
}

# Mappings to rename/align schemas and their references before resolution/merging
SCHEMA_RENAME_MAPPINGS = {
    "GenerateContentResponsePromptFeedback": "PromptFeedback",
    "GenerateContentResponseUsageMetadata": "UsageMetadata",
    "ToolGoogleSearch": "GoogleSearch",
    "ToolComputerUse": "ComputerUse",
    "ToolCodeExecution": "CodeExecution",
    "GenerationConfigThinkingConfig": "ThinkingConfig",
    "GoogleTypeLatLng": "LatLng",
    "PartMediaResolution": "MediaResolution",
    "LogprobsResultTopCandidates": "TopCandidates",
    "GoogleAiGenerativelanguageV1betaGroundingSupport": "GroundingSupport",
    "GoogleAiGenerativelanguageV1betaSegment": "Segment",
    "GroundingChunkImage": "ImageChunk",
    "GroundingChunkRetrievedContext": "RetrievedContextChunk",
    "GroundingChunkWeb": "WebChunk",
    "GroundingChunkMaps": "MapsChunk",
    "ToolGoogleSearchSearchTypes": "SearchTypes",
    "ToolGoogleSearchWebSearch": "WebSearch",
    "ToolGoogleSearchImageSearch": "ImageSearch",
    "GroundingChunkMapsPlaceAnswerSources": "PlaceAnswerSources",
    "GroundingChunkMapsPlaceAnswerSourcesReviewSnippet": "ReviewSnippet",
    "GroundingChunkMapsRoute": "MapsRoute"
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
        if name in visited or name in EXCLUDED_SCHEMAS or name in MANUAL_OVERRIDE_SCHEMAS:
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


def process_resolved_schemas(resolved_schemas, cycle_nodes, namespace):
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
        for prop_name, prop_data in properties.items():
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
                
            is_prop_deprecated = prop_data.get("deprecated", False)
            if not is_prop_deprecated:
                if "$ref" in prop_data:
                    ref_name = prop_data["$ref"]
                    if ref_name in resolved_schemas and resolved_schemas[ref_name].get("deprecated", False):
                        is_prop_deprecated = True
                elif prop_data.get("type") == "array" and "items" in prop_data:
                    items_data = prop_data["items"]
                    if "$ref" in items_data:
                        ref_name = items_data["$ref"]
                        if ref_name in resolved_schemas and resolved_schemas[ref_name].get("deprecated", False):
                            is_prop_deprecated = True
                
            st.properties.append(SwiftProperty(
                swift_name=swift_prop_name,
                json_name=prop_name,
                swift_type=swift_type_str,
                description=prop_data.get("description"),
                is_deprecated=is_prop_deprecated
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
        process_schema(name, data, namespace)
        
    return swift_types


def strip_prefix_from_schemas(schemas, prefix):
    if not prefix:
        return schemas
        
    def strip_prefix_from_value(val):
        if isinstance(val, dict):
            new_dict = {}
            for k, v in val.items():
                if k == "$ref" and isinstance(v, str) and v.startswith(prefix):
                    new_dict[k] = v[len(prefix):]
                else:
                    new_dict[k] = strip_prefix_from_value(v)
            return new_dict
        elif isinstance(val, list):
            return [strip_prefix_from_value(item) for item in val]
        return val

    new_schemas = {}
    for schema_name, schema_data in schemas.items():
        new_name = schema_name
        if schema_name.startswith(prefix):
            new_name = schema_name[len(prefix):]
        new_schemas[new_name] = strip_prefix_from_value(schema_data)
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
                if k == "$ref" and isinstance(v, str) and v in mappings:
                    new_dict[k] = mappings[v]
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
        
        if st.kind == "struct":
            rendered = struct_tmpl.render(
                namespace=st.namespace,
                name=st.name,
                description=st.description,
                is_deprecated=st.is_deprecated,
                properties=st.properties,
                uses_foundation_types=any("Date" in p.swift_type for p in st.properties),
                uses_shared_data_models=any("JSONValue" in p.swift_type or "APIError" in p.swift_type for p in st.properties),
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
                uses_shared_data_models=any("JSONValue" in p.swift_type or "APIError" in p.swift_type for p in st.properties),
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
        if existing.endswith(".swift") and existing != f"{root_namespace}.swift":
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
        all_sub_names = set(sub_props1.keys()) | set(sub_props2.keys())
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
    
    all_prop_names = set(props1.keys()) | set(props2.keys())
    merged_props = {}
    
    for prop_name in all_prop_names:
        if prop_name in props1 and prop_name in props2:
            merged_props[prop_name] = merge_properties(name, prop_name, props1[prop_name], props2[prop_name])
        elif prop_name in props1:
            prop = dict(props1[prop_name])
            desc = prop.get("description", "")
            note = f"> Important: `{prop_name}` is only available in the Gemini Developer API."
            prop["description"] = f"{desc}\n\n{note}" if desc else note
            merged_props[prop_name] = prop
        else:
            prop = dict(props2[prop_name])
            desc = prop.get("description", "")
            note = f"> Important: `{prop_name}` is only available in the Gemini Enterprise Agent Platform."
            prop["description"] = f"{desc}\n\n{note}" if desc else note
            merged_props[prop_name] = prop
            
    merged["properties"] = merged_props
    return merged


def main():
    parser = argparse.ArgumentParser(description="Generate Swift types from one or more Google Discovery Documents.")
    parser.add_argument("--discovery-doc", nargs="+", default=[
                            "utilities/discovery_documents/firebasevertexai-discovery.json",
                            "utilities/discovery_documents/firebasevertexai-discovery.json"
                        ],
                        help="Path(s) to the Google Discovery Document JSON file(s).")
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
    parser.add_argument("--verbose", action="store_true",
                        help="Print detailed generation progress (e.g. list of generated files).")
    args = parser.parse_args()
    
    resolved_by_doc = []
    for idx, doc_path in enumerate(args.discovery_doc):
        if not os.path.exists(doc_path):
            print(f"Error: Discovery document not found at {doc_path}")
            sys.exit(1)
            
        with open(doc_path, "r") as f:
            doc = json.load(f)
            
        doc_schemas = doc.get("schemas", {})
        print(f"Loaded discovery document {doc_path} with {len(doc_schemas)} schemas.")
        
        # Strip prefix if requested for this document
        prefix = args.strip_prefix[idx] if idx < len(args.strip_prefix) else ""
        if prefix:
            doc_schemas = strip_prefix_from_schemas(doc_schemas, prefix)
            print(f"Stripped prefix '{prefix}' for {doc_path}. Remaining schema count: {len(doc_schemas)}")
            
        # Rename/align schemas to match across backends
        doc_schemas = rename_schemas_and_refs(doc_schemas, SCHEMA_RENAME_MAPPINGS)
            
        # Resolve transitively for this document
        doc_resolved = resolve_all_types(doc_schemas, args.roots)
        print(f"Resolved {len(doc_resolved)} schemas for {doc_path} from roots {args.roots}.")
        resolved_by_doc.append(doc_resolved)
        
    # Merge resolved schemas from all documents
    resolved = {}
    for doc_resolved in resolved_by_doc:
        for name, data in doc_resolved.items():
            if name in resolved:
                resolved[name] = merge_schemas(name, resolved[name], data)
            else:
                resolved[name] = data
                
    # Annotate standalone types and properties that only exist in one document
    gl_schemas = resolved_by_doc[0]
    ai_schemas = resolved_by_doc[1] if len(resolved_by_doc) > 1 else {}
    for name, schema in resolved.items():
        is_gl = name in gl_schemas
        is_ai = name in ai_schemas
        if is_gl and not is_ai:
            desc = schema.get("description", "")
            note = "> Important: This type is only available in the Gemini Developer API."
            schema["description"] = f"{desc}\n\n{note}" if desc else note
            if "properties" in schema:
                for prop_name, prop_data in schema["properties"].items():
                    p_desc = prop_data.get("description", "")
                    p_note = f"> Important: `{prop_name}` is only available in the Gemini Developer API."
                    prop_data["description"] = f"{p_desc}\n\n{p_note}" if p_desc else p_note
        elif is_ai and not is_gl:
            desc = schema.get("description", "")
            note = "> Important: This type is only available in the Gemini Enterprise Agent Platform."
            schema["description"] = f"{desc}\n\n{note}" if desc else note
            if "properties" in schema:
                for prop_name, prop_data in schema["properties"].items():
                    p_desc = prop_data.get("description", "")
                    p_note = f"> Important: `{prop_name}` is only available in the Gemini Enterprise Agent Platform."
                    prop_data["description"] = f"{p_desc}\n\n{p_note}" if p_desc else p_note
                
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

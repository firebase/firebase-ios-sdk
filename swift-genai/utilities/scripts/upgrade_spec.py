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

import json
import os
import sys
import yaml

def upgrade_nullables(node):
    """
    Recursively finds "nullable": true in the OpenAPI spec and converts it to
    OpenAPI 3.1.0 format (e.g. type: [type, "null"] or oneOf: [$ref, {type: "null"}]).
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
        
        for k, v in list(node.items()):
            upgrade_nullables(v)
    elif isinstance(node, list):
        for item in node:
            upgrade_nullables(item)

def simplify_all_of(node):
    """
    Recursively simplifies single-element allOf wrappers containing only a $ref
    since OpenAPI 3.1.0 allows sibling fields next to $ref.
    """
    if isinstance(node, dict):
        if "allOf" in node and isinstance(node["allOf"], list) and len(node["allOf"]) == 1:
            item = node["allOf"][0]
            if isinstance(item, dict) and "$ref" in item and len(item) == 1:
                ref = item["$ref"]
                node.pop("allOf")
                node["$ref"] = ref
        
        for k, v in list(node.items()):
            simplify_all_of(v)
    elif isinstance(node, list):
        for item in node:
            simplify_all_of(item)

def deep_merge(source, destination):
    """
    Deep merges source dict into destination dict.
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

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    docs_dir = os.path.join(base_dir, "discovery_documents")
    
    input_path = os.path.join(docs_dir, "firebasevertexai_public_openapi3_0_v1beta.json")
    overrides_path = os.path.join(docs_dir, "firebasevertexai-overrides.yaml")
    output_path = os.path.join(docs_dir, "firebasevertexai-openapi.yaml")
    
    if not os.path.exists(input_path):
        print(f"Error: Base spec file not found at {input_path}")
        sys.exit(1)
        
    if not os.path.exists(overrides_path):
        print(f"Error: Overrides file not found at {overrides_path}")
        sys.exit(1)
        
    # 1. Load OpenAPI 3.0.3 base spec
    print(f"Loading base specification from {input_path}...")
    with open(input_path, "r") as f:
        spec = json.load(f)
        
    # 2. Upgrade metadata to OpenAPI 3.1.0
    spec["openapi"] = "3.1.0"
    
    # 3. Upgrade nullables to standard JSON Schema Draft 2020-12
    print("Upgrading nullables...")
    upgrade_nullables(spec)
    
    # 4. Simplify single-element allOf wrappers
    print("Simplifying allOf wrappers...")
    simplify_all_of(spec)
    
    # 5. Load and apply overrides
    print(f"Applying manual overrides from {overrides_path}...")
    with open(overrides_path, "r") as f:
        overrides = yaml.safe_load(f)
        
    if overrides and "schemas" in overrides:
        schemas = spec.setdefault("components", {}).setdefault("schemas", {})
        deep_merge(overrides["schemas"], schemas)
        
    # 6. Output the upgraded spec as YAML
    print(f"Saving upgraded specification to {output_path}...")
    with open(output_path, "w") as f:
        yaml.safe_dump(spec, f, sort_keys=False, default_flow_style=False)
        
    print("Upgrade completed successfully.")

if __name__ == "__main__":
    main()

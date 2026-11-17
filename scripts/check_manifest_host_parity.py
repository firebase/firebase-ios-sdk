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

"""Checks that Package.swift declares the same package on macOS and Linux.

Tools such as Dependabot resolve Apple apps' dependencies on Linux, so a product, dependency, or
default trait that only exists on one host breaks them (see
https://github.com/firebase/firebase-ios-sdk/issues/16574). Targets may differ, because some only
build with SDKs that Linux doesn't have, as long as they don't add package dependencies.

Usage: check_manifest_host_parity.py <macos-dump.json> <linux-dump.json>
Each file is the output of `swift package dump-package`.
"""

import json
import sys


def summarize(path):
  with open(path) as file:
    dump = json.load(file)
  products = {
      product["name"]: (sorted(product["type"]), sorted(product["targets"]))
      for product in dump["products"]
  }
  dependencies = {}
  for dependency in dump["dependencies"]:
    for kind, values in dependency.items():
      details = values[0]
      dependencies[details.get("identity", json.dumps(details, sort_keys=True))] = json.dumps(
          {"kind": kind, "requirement": details.get("requirement")}, sort_keys=True)
  traits = {
      trait["name"]: sorted(trait.get("enabledTraits", []))
      for trait in dump.get("traits", [])
  }
  return {"products": products, "dependencies": dependencies, "traits": traits}


def main():
  if len(sys.argv) != 3:
    print(__doc__)
    return 2
  macos, linux = summarize(sys.argv[1]), summarize(sys.argv[2])
  problems = []
  for section in ("products", "dependencies", "traits"):
    for name in sorted(set(macos[section]) | set(linux[section])):
      if name not in linux[section]:
        problems.append(f"{section}: '{name}' is only declared on macOS")
      elif name not in macos[section]:
        problems.append(f"{section}: '{name}' is only declared on Linux")
      elif macos[section][name] != linux[section][name]:
        problems.append(f"{section}: '{name}' differs: macOS {macos[section][name]}, "
                        f"Linux {linux[section][name]}")
  if problems:
    print("Package.swift declares a different package on macOS and Linux:")
    for problem in problems:
      print(f"  {problem}")
    return 1
  print(f"Package.swift matches on macOS and Linux: {len(macos['products'])} products, "
        f"{len(macos['dependencies'])} dependencies, {len(macos['traits'])} traits.")
  return 0


if __name__ == "__main__":
  sys.exit(main())

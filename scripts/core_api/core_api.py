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

"""API parity gate for FirebaseCore.

FirebaseCore's public Swift and Objective-C APIs must not change while the
module is reimplemented in Swift. This tool records the API surface and
compares a candidate surface against the committed baselines in
FirebaseCore/Tests/APIBaselines.

  dump   Write the current API surface to a directory.
  check  Compare the current API surface with the committed baselines.
  update Regenerate the committed baselines (only when an API change has been
         reviewed and approved).

Two surfaces are recorded:

  swift/<platform>.json         swift-api-digester dump of the Swift view of
                                the FirebaseCore module, per platform.
  swift/FirebaseCore.swiftinterface
                                Human-readable Swift view (iOS), for review.
  objc/FirebaseCore.symbols.json
                                Normalized `clang -extract-api` symbol graph of
                                the Objective-C public headers.

By default the module is built from the Objective-C public headers. Use
--swift-module-path once FirebaseCore is a Swift module, to point at the
directory containing FirebaseCore.swiftmodule for each platform, and
--objc-header to point at the umbrella header plus generated
FirebaseCore-Swift.h.

The baselines depend on the toolchain. Run with the Xcode recorded in
metadata.json (set DEVELOPER_DIR), which is the Xcode that the api-baselines
job in .github/workflows/sdk.core.yml uses.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BASELINE_DIR = os.path.join(REPO_ROOT, "FirebaseCore", "Tests", "APIBaselines")
PUBLIC_HEADERS_DIR = os.path.join(
    REPO_ROOT, "FirebaseCore", "Sources", "Public", "FirebaseCore"
)
UMBRELLA_HEADER = os.path.join(PUBLIC_HEADERS_DIR, "FirebaseCore.h")
MODULE = "FirebaseCore"

# name -> (xcrun sdk, target triple)
PLATFORMS = {
    "ios": ("iphonesimulator", "arm64-apple-ios15.0-simulator"),
    "catalyst": ("macosx", "arm64-apple-ios15.0-macabi"),
    "macos": ("macosx", "arm64-apple-macos11.0"),
    "tvos": ("appletvsimulator", "arm64-apple-tvos15.0-simulator"),
    "watchos": ("watchsimulator", "arm64-apple-watchos8.0-simulator"),
}
INTERFACE_PLATFORM = "ios"

# Keys in digester dumps that differ between machines or don't describe API.
VOLATILE_KEYS = {"location", "tool_arguments"}

# Diagnostics from `swift-api-digester -diagnose-sdk` that are noise when one
# side is a Clang module and the other a Swift module.
NOISE_PATTERNS = [
    # Builtin Clang typealiases that appear in dumps of Clang modules only.
    re.compile(r"TypeAlias __\w+ has been removed"),
    # Swift dumps omit implicit ObjC names. Selectors are checked by the
    # Objective-C gate and the runtime ABI test instead.
    re.compile(r"has ObjC name change from \S+ to\s*$"),
]
SECTION_HEADER = re.compile(r"^/\* .* \*/$")


def log(message):
  print(message, file=sys.stderr)


def run(cmd, **kwargs):
  try:
    return subprocess.run(
        cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        universal_newlines=True, **kwargs
    )
  except subprocess.CalledProcessError as error:
    log("Command failed: " + " ".join(cmd))
    log(error.stdout)
    log(error.stderr)
    raise


def xcrun(*args):
  return run(["xcrun"] + list(args)).stdout.strip()


def toolchain_version():
  return xcrun("swiftc", "--version").splitlines()[0]


def sdk_path(sdk):
  return xcrun("--sdk", sdk, "--show-sdk-path")


def write_json(path, value):
  os.makedirs(os.path.dirname(path), exist_ok=True)
  with open(path, "w", encoding="utf-8") as f:
    json.dump(value, f, indent=2, sort_keys=True)
    f.write("\n")


def read_json(path):
  with open(path, encoding="utf-8") as f:
    return json.load(f)


# ---------------------------------------------------------------------------
# Swift surface


def header_module_dir(work_dir, umbrella):
  """Creates a module map for the Objective-C public headers."""
  module_dir = os.path.join(work_dir, "modulemap")
  os.makedirs(module_dir, exist_ok=True)
  module_map = os.path.join(module_dir, "module.modulemap")
  with open(module_map, "w", encoding="utf-8") as f:
    f.write(
        'module %s {\n  umbrella header "%s"\n  export *\n}\n'
        % (MODULE, umbrella)
    )
  return module_dir


def normalize_digester(node):
  if isinstance(node, dict):
    result = {}
    for key, value in node.items():
      if key in VOLATILE_KEYS:
        continue
      if key == "children" and isinstance(value, list):
        value = [
            child for child in value
            if not (
                isinstance(child, dict)
                and child.get("declKind") == "TypeAlias"
                and child.get("name", "").startswith("__")
            )
        ]
      result[key] = normalize_digester(value)
    return result
  if isinstance(node, list):
    return [normalize_digester(item) for item in node]
  return node


def search_args(platform, args, work_dir):
  if args.swift_module_path:
    paths = [p.replace("{platform}", platform) for p in args.swift_module_path]
  else:
    paths = [header_module_dir(work_dir, args.umbrella_header)]
  result = []
  for path in paths:
    result += ["-I", path]
  return result


def dump_swift(out_dir, args, work_dir):
  for platform, (sdk, target) in sorted(PLATFORMS.items()):
    log("Dumping Swift API for %s" % platform)
    raw = os.path.join(work_dir, "%s.raw.json" % platform)
    cmd = [
        "xcrun", "swift-api-digester", "-dump-sdk", "-module", MODULE,
        "-sdk", sdk_path(sdk), "-target", target,
        "-module-cache-path", os.path.join(work_dir, "mcache-" + platform),
        "-o", raw,
    ] + search_args(platform, args, work_dir)
    run(cmd)
    write_json(
        os.path.join(out_dir, "swift", platform + ".json"),
        normalize_digester(read_json(raw)),
    )

  sdk, target = PLATFORMS[INTERFACE_PLATFORM]
  interface = os.path.join(out_dir, "swift", MODULE + ".swiftinterface")
  cmd = [
      "xcrun", "swift-synthesize-interface", "-module-name", MODULE,
      "-sdk", sdk_path(sdk), "-target", target,
      "-module-cache-path", os.path.join(work_dir, "mcache-interface"),
      "-o", interface,
  ] + search_args(INTERFACE_PLATFORM, args, work_dir)
  run(cmd)


def surface_decls(node, path=()):
  """Yields (declKind, qualified printed name) for every declaration."""
  if not isinstance(node, dict):
    return
  decl_kind = node.get("declKind")
  if decl_kind and decl_kind != "Import":
    path = path + (node.get("printedName", node.get("name", "")),)
    yield (decl_kind, ".".join(path))
  for child in node.get("children", []):
    if isinstance(child, dict) and child.get("declKind"):
      for item in surface_decls(child, path):
        yield item


def check_swift(baseline_dir, current_dir, allow):
  problems = []
  for platform in sorted(PLATFORMS):
    base = os.path.join(baseline_dir, "swift", platform + ".json")
    current = os.path.join(current_dir, "swift", platform + ".json")
    result = subprocess.run(
        [
            "xcrun", "swift-api-digester", "-diagnose-sdk", "-module", MODULE,
            "-input-paths", base, "-input-paths", current,
        ],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        universal_newlines=True,
    )
    for line in result.stdout.splitlines():
      line = line.strip()
      if not line or SECTION_HEADER.match(line):
        continue
      if any(p.search(line) for p in NOISE_PATTERNS):
        continue
      problems.append("swift[%s]: %s" % (platform, line))

    # The digester reports breaking changes only. Additions also change the
    # public API, so report them too.
    base_decls = set(surface_decls(read_json(base)["ABIRoot"]))
    current_decls = set(surface_decls(read_json(current)["ABIRoot"]))
    for kind, name in sorted(current_decls - base_decls):
      problems.append(
          "swift[%s]: %s %s has been added" % (platform, kind, name))
  return [p for p in problems if not allowed(p, allow.get("swift", []))]


# ---------------------------------------------------------------------------
# Objective-C surface

NULLABILITY_TOKENS = {"nullable", "_Nullable", "__nullable", "nonnull",
                      "_Nonnull", "__nonnull", "null_unspecified",
                      "_Null_unspecified", "null_resettable"}
# Property attributes that are defaults, so their presence doesn't change the
# API.
DEFAULT_PROPERTY_ATTRIBUTES = {"readwrite", "atomic"}


def normalize_property_attributes(declaration):
  """Sorts property attributes and drops nullability and default attributes."""
  match = re.match(r"^@property \(([^)]*)\)(.*)$", declaration)
  if not match:
    return declaration
  attributes = [a.strip() for a in match.group(1).split(",")]
  attributes = sorted(
      a for a in attributes
      if a and a not in NULLABILITY_TOKENS
      and a not in DEFAULT_PROPERTY_ATTRIBUTES
  )
  return "@property (%s)%s" % (", ".join(attributes), match.group(2))


def normalize_objc_symbol(symbol):
  # `clang -extract-api` drops nullability from method signatures, so
  # nullability is not compared here. It's covered by the Swift gate: the
  # Swift view of a header shows nullability as optionality, and a Swift
  # module's generated header derives its nullability from Swift types.
  tokens = []
  for fragment in symbol.get("declarationFragments", []):
    text = fragment.get("spelling", "")
    if text.strip() in NULLABILITY_TOKENS:
      continue
    tokens.append(text)
  declaration = re.sub(r"\s+", " ", "".join(tokens)).strip()
  declaration = re.sub(r"\s*\*\s*", " *", declaration)
  declaration = normalize_property_attributes(declaration)
  deprecated = any(
      item.get("isUnconditionallyDeprecated") or "deprecated" in item
      for item in symbol.get("availability", [])
  )
  return {
      "kind": symbol["kind"]["identifier"],
      "path": ".".join(symbol.get("pathComponents", [])),
      "declaration": declaration,
      "deprecated": deprecated,
  }


def dump_objc(out_dir, args, work_dir):
  log("Extracting Objective-C API")
  sdk, target = PLATFORMS[INTERFACE_PLATFORM]
  raw = os.path.join(work_dir, "objc.raw.json")
  headers = args.objc_header or sorted(
      os.path.join(PUBLIC_HEADERS_DIR, name)
      for name in os.listdir(PUBLIC_HEADERS_DIR) if name.endswith(".h")
  )
  cmd = [
      "xcrun", "clang", "-extract-api", "--product-name=" + MODULE,
      "-x", "objective-c-header", "-isysroot", sdk_path(sdk), "-target", target,
      "-I", os.path.dirname(PUBLIC_HEADERS_DIR),
      "-fmodules",
      "-fmodules-cache-path=" + os.path.join(work_dir, "mcache-objc"),
      "-o", raw,
  ]
  for include in args.objc_include or []:
    cmd += ["-I", include]
  run(cmd + headers)
  graph = read_json(raw)
  symbols = {}
  for symbol in graph.get("symbols", []):
    symbols[symbol["identifier"]["precise"]] = normalize_objc_symbol(symbol)
  write_json(os.path.join(out_dir, "objc", MODULE + ".symbols.json"), symbols)


def check_objc(baseline_dir, current_dir, allow):
  name = os.path.join("objc", MODULE + ".symbols.json")
  base = read_json(os.path.join(baseline_dir, name))
  current = read_json(os.path.join(current_dir, name))
  problems = []
  for usr in sorted(set(base) - set(current)):
    problems.append("objc: %s has been removed" % usr)
  for usr in sorted(set(current) - set(base)):
    problems.append("objc: %s has been added" % usr)
  for usr in sorted(set(base) & set(current)):
    for key in ("kind", "declaration", "deprecated"):
      if base[usr][key] != current[usr][key]:
        problems.append(
            "objc: %s %s changed from %r to %r"
            % (usr, key, base[usr][key], current[usr][key])
        )
  return [p for p in problems if not allowed(p, allow.get("objc", []))]


# ---------------------------------------------------------------------------
# Commands


def allowed(problem, entries):
  for entry in entries:
    if re.search(entry["pattern"], problem):
      return True
  return False


def load_allowlist():
  path = os.path.join(BASELINE_DIR, "allowlist.json")
  if not os.path.exists(path):
    return {}
  return read_json(path)


def dump(out_dir, args):
  work_dir = tempfile.mkdtemp(prefix="core_api_")
  try:
    dump_swift(out_dir, args, work_dir)
    dump_objc(out_dir, args, work_dir)
  finally:
    shutil.rmtree(work_dir, ignore_errors=True)
  write_json(
      os.path.join(out_dir, "metadata.json"),
      {"toolchain": toolchain_version()},
  )


def cmd_dump(args):
  dump(args.out, args)


def cmd_update(args):
  dump(BASELINE_DIR, args)
  log("Updated baselines in %s" % BASELINE_DIR)


def cmd_check(args):
  metadata = read_json(os.path.join(BASELINE_DIR, "metadata.json"))
  current_toolchain = toolchain_version()
  if metadata["toolchain"] != current_toolchain:
    log(
        "warning: baselines were generated with '%s' but the current toolchain "
        "is '%s'. Set DEVELOPER_DIR to the baseline Xcode."
        % (metadata["toolchain"], current_toolchain)
    )
  current_dir = args.current
  temp_dir = None
  try:
    if not current_dir:
      temp_dir = tempfile.mkdtemp(prefix="core_api_current_")
      current_dir = temp_dir
      dump(current_dir, args)
    allow = load_allowlist()
    problems = check_swift(BASELINE_DIR, current_dir, allow)
    problems += check_objc(BASELINE_DIR, current_dir, allow)
  finally:
    if temp_dir:
      shutil.rmtree(temp_dir, ignore_errors=True)
  if problems:
    log("FirebaseCore public API changed:")
    for problem in problems:
      log("  " + problem)
    log(
        "If the change is intended and approved, add an entry to "
        "FirebaseCore/Tests/APIBaselines/allowlist.json, or regenerate the "
        "baselines with `scripts/core_api/core_api.py update`."
    )
    return 1
  log("FirebaseCore public API matches the baselines.")
  return 0


def add_surface_args(parser):
  parser.add_argument(
      "--umbrella-header", default=UMBRELLA_HEADER,
      help="Umbrella header used to build the module from Objective-C headers.",
  )
  parser.add_argument(
      "--swift-module-path", action="append",
      help="Directory containing FirebaseCore.swiftmodule. May contain "
      "'{platform}'. Repeat for dependencies. Replaces the header-based "
      "module.",
  )
  parser.add_argument(
      "--objc-header", action="append",
      help="Header to extract the Objective-C API from. Repeatable. Defaults "
      "to every public header.",
  )
  parser.add_argument(
      "--objc-include", action="append",
      help="Extra include directory for Objective-C extraction. Repeatable.",
  )


def main():
  parser = argparse.ArgumentParser(
      description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
  subparsers = parser.add_subparsers(dest="command")
  subparsers.required = True

  dump_parser = subparsers.add_parser("dump", help="Write the current API.")
  dump_parser.add_argument("--out", required=True)
  add_surface_args(dump_parser)
  dump_parser.set_defaults(func=cmd_dump)

  update_parser = subparsers.add_parser("update", help="Regenerate baselines.")
  add_surface_args(update_parser)
  update_parser.set_defaults(func=cmd_update)

  check_parser = subparsers.add_parser("check", help="Compare with baselines.")
  check_parser.add_argument(
      "--current", help="Directory from a previous `dump`. Dumps if omitted."
  )
  add_surface_args(check_parser)
  check_parser.set_defaults(func=cmd_check)

  args = parser.parse_args()
  sys.exit(args.func(args) or 0)


if __name__ == "__main__":
  main()

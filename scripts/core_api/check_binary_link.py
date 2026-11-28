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

"""Binary link gate for FirebaseCore.

The prebuilt FirebaseAnalytics and GoogleAppMeasurement binaries were compiled
against FirebaseCore and can't be rebuilt. This tool records what they use
from FirebaseCore and checks that a FirebaseCore build still provides it.

  symbols    Undefined symbols of the binaries, such as _FIRFirebaseVersion
             and _OBJC_CLASS_$_FIRApp, and the product that provides each.
             FirebaseCore must define and export the ones it provides, both
             when it's linked statically and when it's a dynamic library.
  selectors  Objective-C selectors that the binaries use and that
             FirebaseCore's classes and protocols implement. Each must be
             covered by the runtime ABI contract in
             FirebaseCore/Tests/RuntimeABI/FIRCoreRuntimeABITests.m, unless
             it's an NSObject selector.
  names      Class, protocol, notification and key names in the binaries,
             which they look up as strings at run time. Each name that is a
             FirebaseCore class or protocol, or a string in FirebaseCore's
             sources, must be pinned by a FirebaseCore test.

check fails if FirebaseCore doesn't provide something the binaries use, or if
the contract doesn't cover it. Other differences from the baseline, such as a
selector a new binary no longer uses, are reported as notes.

Commands:

  list    Print what each binary uses.
  check   Compare with FirebaseCore/Tests/APIBaselines/binary_link.json, and
          check the FirebaseCore builds given with --static and --dynamic.
  update  Rewrite binary_link.json. Only do this after reviewing the change,
          for example after updating the FirebaseAnalytics binary.

The binaries come from a resolved Swift package (--workspace-state, by default
.build/workspace-state.json). The FirebaseCore builds are Swift Build products
directories, from `xcodebuild` (DerivedData/Build/Products/Debug) or
`swift build` (.build/out/Products/Debug). Both options can be repeated.

  --static DIR   Products of the root package's CoreAnalyticsLink test. Uses
                 Firebase.o and FirebaseCore*.o.
  --dynamic DIR  Products of scripts/core_api/binary_link, which builds
                 FirebaseCore as dynamic libraries. Uses the Firebase and
                 FirebaseCore* dylibs or frameworks.
  --dynamic-client FILE
                 A binary linked against the --dynamic libraries. Checks that
                 it gets FirebaseCore's symbols from them rather than from a
                 static copy.

See FirebaseCore/Tests/APIBaselines/README.md.
"""

import argparse
import glob
import json
import os
import plistlib
import re
import subprocess
import sys

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BASELINE = os.path.join(
    REPO_ROOT, "FirebaseCore", "Tests", "APIBaselines", "binary_link.json"
)
BASELINE_NAME = os.path.relpath(BASELINE, REPO_ROOT)
RUNTIME_ABI_TEST = os.path.join(
    REPO_ROOT, "FirebaseCore", "Tests", "RuntimeABI", "FIRCoreRuntimeABITests.m"
)
# Where FirebaseCore's implementation and internal headers live.
CORE_SOURCE_DIRS = [
    os.path.join(REPO_ROOT, "FirebaseCore", "Sources"),
    os.path.join(REPO_ROOT, "FirebaseCore", "Extension"),
]
# FirebaseCore tests that pin names other code depends on.
CORE_CONTRACT_TEST_DIRS = [
    os.path.join(REPO_ROOT, "FirebaseCore", "Tests", "RuntimeABI"),
    os.path.join(REPO_ROOT, "FirebaseCore", "Tests", "SwiftSuite"),
    os.path.join(REPO_ROOT, "FirebaseCore", "Tests", "AnalyticsLink"),
]

CORE = "FirebaseCore"
# The binaries to check, by Swift package binary target name.
BINARIES = [
    "FirebaseAnalytics",
    "GoogleAppMeasurement",
    "GoogleAppMeasurementIdentitySupport",
]
# Symbols that FirebaseAnalytics is known to need. FirebaseCore must always
# export them, whatever the baseline says.
REQUIRED_SYMBOLS = [
    "_FIRFirebaseVersion",
    "_OBJC_CLASS_$_FIRApp",
    "_OBJC_CLASS_$_FIRComponent",
    "_kFIRLoggerAnalytics",
]
# Undefined symbols that may come from a Firebase product.
FIREBASE_SYMBOL = re.compile(
    r"^_(?:OBJC_(?:CLASS|METACLASS|EHTYPE|IVAR)_\$_)?k?FIR"
)
# Strings that may be Firebase class, protocol, notification or key names.
FIREBASE_NAME = re.compile(r"^(?=.*(?:FIR|FIREBASE))[A-Za-z_][A-Za-z0-9_]*$")
# Selectors that every NSObject implements. FirebaseCore's classes override
# some of them, but the binaries don't depend on FirebaseCore for them, and
# whether an override shows up in the metadata depends on the language.
NSOBJECT_SELECTORS = {
    ".cxx_destruct",
    "class",
    "copy",
    "copyWithZone:",
    "dealloc",
    "debugDescription",
    "description",
    "hash",
    "init",
    "isEqual:",
}
METHOD_LIST_HEADERS = {
    "baseMethods",
    "instanceMethods",
    "classMethods",
    "optionalInstanceMethods",
    "optionalClassMethods",
}
METHOD_LIST_FIELDS = {"name", "types", "imp", "entsize", "count"}


class GateError(Exception):
  pass


def log(message=""):
  print(message, file=sys.stderr)


def run(cmd):
  result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
  if result.returncode != 0:
    raise GateError(
        "Command failed: %s\n%s"
        % (" ".join(cmd), result.stderr.decode("utf-8", "replace"))
    )
  return result.stdout.decode("utf-8", "replace")


def read_json(path):
  with open(path, encoding="utf-8") as f:
    return json.load(f)


def write_json(path, value):
  with open(path, "w", encoding="utf-8") as f:
    json.dump(value, f, indent=2, sort_keys=True)
    f.write("\n")


# ---------------------------------------------------------------------------
# Mach-O inspection


def archs(path):
  return run(["xcrun", "lipo", "-archs", path]).split()


def nm_names(path, arch, flags):
  """Symbol names from `nm -j`, without archive member headers."""
  names = set()
  output = run(["xcrun", "nm", "-arch", arch, "-j"] + flags + [path])
  for line in output.splitlines():
    line = line.strip()
    if line and not line.endswith(":"):
      names.add(line)
  return names


def exported_symbols(path, arch):
  """Defined symbols that other images and object files can link against."""
  names = set()
  pattern = re.compile(r"^[0-9a-f]+ \([^)]*\) (?:weak )?external (\S+)")
  for line in run(["xcrun", "nm", "-arch", arch, "-m", path]).splitlines():
    match = pattern.match(line)
    if match:
      names.add(match.group(1))
  return names


def section_strings(path, arch, segment, section):
  strings = set()
  output = run(
      ["xcrun", "otool", "-arch", arch, "-v", "-s", segment, section, path]
  )
  for line in output.splitlines():
    match = re.match(r"^[0-9a-f]+\s+(.+)$", line)
    if match:
      strings.add(match.group(1).strip())
  return strings


def defined_selectors(path, arch, owner_pattern=None):
  """Selectors of methods that classes, categories and protocols define.

  If `owner_pattern` is set, only methods of classes, categories and protocols
  whose name matches it are returned.
  """
  selectors = set()
  in_method_list = False
  owner = ""
  output = run(["xcrun", "otool", "-arch", arch, "-oV", path])
  for line in output.splitlines():
    fields = line.split()
    if not fields:
      continue
    head = fields[0]
    if head in METHOD_LIST_HEADERS:
      in_method_list = True
      continue
    if head not in METHOD_LIST_FIELDS:
      in_method_list = False
      if head == "cls" and len(fields) > 2:
        owner = fields[-1]
      continue
    if head != "name" or len(fields) < 3:
      continue
    if in_method_list:
      if owner_pattern is None or owner_pattern.search(owner):
        selectors.add(fields[-1])
    else:
      # The name of a class, category or protocol.
      owner = fields[-1]
  return selectors


# ---------------------------------------------------------------------------
# The binaries


class Slice:
  """One architecture of one platform of an xcframework."""

  def __init__(self, binary, identifier, path, arch):
    self.binary = binary
    self.identifier = identifier
    self.path = path
    self.arch = arch

  def __str__(self):
    return "%s %s %s" % (self.binary, self.identifier, self.arch)


def find_xcframeworks(workspace_state):
  if not os.path.exists(workspace_state):
    raise GateError(
        "%s doesn't exist. Run `swift package resolve` first." % workspace_state
    )
  paths = {}
  for artifact in read_json(workspace_state)["object"]["artifacts"]:
    paths[artifact["targetName"]] = artifact["path"]
  missing = [name for name in BINARIES if name not in paths]
  if missing:
    raise GateError(
        "%s has no artifacts for %s." % (workspace_state, ", ".join(missing))
    )
  return {name: paths[name] for name in BINARIES}


def slices(name, xcframework):
  with open(os.path.join(xcframework, "Info.plist"), "rb") as f:
    info = plistlib.load(f)
  result = []
  for library in sorted(
      info["AvailableLibraries"], key=lambda lib: lib["LibraryIdentifier"]
  ):
    identifier = library["LibraryIdentifier"]
    binary_path = library.get("BinaryPath")
    if not binary_path:
      framework = library["LibraryPath"]
      binary_path = os.path.join(framework, os.path.splitext(framework)[0])
    path = os.path.join(xcframework, identifier, binary_path)
    for arch in library["SupportedArchitectures"]:
      result.append(Slice(name, identifier, path, arch))
  return result


class BinaryUsage:
  """What one binary uses, across all its slices."""

  def __init__(self, name):
    self.name = name
    # Symbol -> slices that need it.
    self.symbols = {}
    self.selectors = set()
    self.names = set()
    self.slice_names = []


def binary_usage(name, xcframework):
  usage = BinaryUsage(name)
  for binary_slice in slices(name, xcframework):
    usage.slice_names.append(str(binary_slice))
    path, arch = binary_slice.path, binary_slice.arch
    defined = nm_names(path, arch, ["-U"])
    undefined = nm_names(path, arch, ["-u"]) - defined
    for symbol in undefined:
      if FIREBASE_SYMBOL.match(symbol):
        usage.symbols.setdefault(symbol, []).append(str(binary_slice))
    # Selectors in __objc_methname, and selectors called through
    # objc_msgSend stubs, whose names are only in the stub symbols.
    usage.selectors |= section_strings(path, arch, "__TEXT", "__objc_methname")
    usage.selectors |= {
        symbol[len("_objc_msgSend$"):]
        for symbol in undefined
        if symbol.startswith("_objc_msgSend$")
    }
    # Names looked up as strings. Leave out the binary's own classes.
    own_classes = {
        symbol[len("_OBJC_CLASS_$_"):]
        for symbol in defined
        if symbol.startswith("_OBJC_CLASS_$_")
    }
    for section in ["__cstring", "__objc_classname"]:
      for string in section_strings(path, arch, "__TEXT", section):
        if FIREBASE_NAME.match(string) and string not in own_classes:
          usage.names.add(string)
  return usage


# ---------------------------------------------------------------------------
# FirebaseCore


class CoreBuild:
  """A FirebaseCore build: object files or dynamic libraries."""

  def __init__(self, kind, directory, paths):
    self.kind = kind
    self.directory = directory
    self.paths = paths
    self._exports = None
    self._selectors = None
    self._objc_names = None

  def __str__(self):
    return "%s FirebaseCore in %s" % (self.kind, self.directory)

  def description(self):
    return "%s (%s)" % (
        self, ", ".join(os.path.basename(path) for path in self.paths)
    )

  def exports(self):
    """Arch -> exported symbols, across all the files."""
    if self._exports is None:
      self._exports = {}
      for path in self.paths:
        for arch in archs(path):
          self._exports.setdefault(arch, set()).update(
              exported_symbols(path, arch)
          )
    return self._exports

  def selectors(self):
    if self._selectors is None:
      self._selectors = set()
      for path in self.paths:
        arch = archs(path)[0]
        self._selectors |= defined_selectors(path, arch, re.compile(r"FIR"))
    return self._selectors

  def objc_names(self):
    """Names of the Objective-C classes and protocols in the files."""
    if self._objc_names is None:
      self._objc_names = set()
      pattern = re.compile(r"^_+OBJC_(?:CLASS|PROTOCOL)_\$_(\w+)$")
      for path in self.paths:
        for symbol in nm_names(path, archs(path)[0], ["-U"]):
          match = pattern.match(symbol)
          if match:
            self._objc_names.add(match.group(1))
    return self._objc_names


# FirebaseCore's targets: the Firebase umbrella target, FirebaseCore and the
# FirebaseCore* targets it's split into, apart from test-only ones.
CORE_TARGET = re.compile(r"^(Firebase|FirebaseCore(?!TestHooks)\w*)$")


def static_core(directory):
  """FirebaseCore's object files in a SwiftPM or Xcode products directory."""
  paths = []
  for path in sorted(glob.glob(os.path.join(directory, "*.o"))):
    if CORE_TARGET.match(os.path.splitext(os.path.basename(path))[0]):
      paths.append(path)
  return CoreBuild("static", directory, require_core(paths, directory))


def dynamic_core(directory):
  """FirebaseCore's dynamic libraries in a products directory.

  `swift build` names them libFirebaseCore.dylib, and Xcode
  PackageFrameworks/FirebaseCore_<hash>_PackageProduct.framework.
  """
  paths = []
  pattern = re.compile(r"^(?:lib)?(\w+?)(?:_[0-9A-F]+_PackageProduct)?$")
  candidates = glob.glob(os.path.join(directory, "*.dylib")) + glob.glob(
      os.path.join(directory, "PackageFrameworks", "*.framework")
  )
  for candidate in sorted(candidates):
    name = os.path.splitext(os.path.basename(candidate))[0]
    match = pattern.match(name)
    if not match or not CORE_TARGET.match(match.group(1)):
      continue
    if candidate.endswith(".framework"):
      binary = os.path.join(candidate, name)
      if not os.path.exists(binary):
        binary = os.path.join(candidate, "Versions", "A", name)
      candidate = binary
    paths.append(candidate)
  return CoreBuild("dynamic", directory, require_core(paths, directory))


def require_core(paths, directory):
  names = [os.path.basename(path) for path in paths]
  if not any(re.match(r"^(lib)?FirebaseCore([._]|$)", n) for n in names):
    raise GateError(
        "No FirebaseCore build in %s. Build the link tests first (see "
        "FirebaseCore/Tests/APIBaselines/README.md)." % directory
    )
  return paths


def runtime_abi_selectors():
  """Selectors in the runtime ABI contract, without their +/- prefix."""
  with open(RUNTIME_ABI_TEST, encoding="utf-8") as f:
    source = f.read()
  return set(re.findall(r'@"[+-]([A-Za-z_.][A-Za-z0-9_:]*)"', source))


def quoted_in(directories, name):
  """Whether `"name"` appears in a source file in `directories`."""
  needle = '"%s"' % name
  for directory in directories:
    for root, _, files in os.walk(directory):
      for file_name in files:
        if os.path.splitext(file_name)[1] not in (".h", ".m", ".mm", ".swift"):
          continue
        with open(os.path.join(root, file_name), encoding="utf-8") as f:
          if needle in f.read():
            return True
  return False


def core_names(names, cores):
  """The names that are FirebaseCore classes or protocols, or that its
  sources use as strings."""
  objc_names = set()
  for core in cores:
    objc_names |= core.objc_names()
  return sorted(
      name
      for name in names
      if name in objc_names or quoted_in(CORE_SOURCE_DIRS, name)
  )


# ---------------------------------------------------------------------------
# Baseline


def baseline_entry(usage, providers, cores, core_selectors):
  names = core_names(usage.names, cores)
  entry = {
      "symbols": providers,
      "names": {
          CORE: names,
          "other": sorted(usage.names - set(names)),
      },
  }
  if core_selectors is not None:
    entry["selectors"] = sorted(shared_selectors(usage, core_selectors))
  return entry


def product_exports(directory, exclude):
  """Target name -> exported symbols, for the object files in `directory`."""
  exports = {}
  if not directory:
    return exports
  for path in sorted(glob.glob(os.path.join(directory, "*.o"))):
    if path in exclude:
      continue
    target = os.path.splitext(os.path.basename(path))[0]
    exports[target] = exported_symbols(path, archs(path)[0])
  return exports


def symbol_providers(usage, old_entry, cores, others):
  """Symbol lists by provider. FirebaseCore's come from the builds, and the
  others from the baseline or from `others`, target name -> exports."""
  old_providers = {}
  for provider, symbols in old_entry.get("symbols", {}).items():
    for symbol in symbols:
      old_providers[symbol] = provider
  exported = set()
  for core in cores:
    for symbols in core.exports().values():
      exported |= symbols
  providers = {}
  unknown = []
  for symbol in sorted(usage.symbols):
    if symbol in exported:
      provider = CORE
    elif symbol in old_providers and old_providers[symbol] != CORE:
      provider = old_providers[symbol]
    elif any(symbol in exports for exports in others.values()):
      provider = [
          target for target, exports in others.items() if symbol in exports
      ][0]
    else:
      unknown.append(symbol)
      continue
    providers.setdefault(provider, []).append(symbol)
  if unknown:
    raise GateError(
        "%s needs %s, which FirebaseCore doesn't export. Add each to\n"
        "%s under the product that provides it, for example\n"
        '"FirebaseInstallations".' % (usage.name, ", ".join(unknown), BASELINE)
    )
  return providers


# ---------------------------------------------------------------------------
# Checks


class Report:
  """Failures, which mean that the contract may be broken, and notes, which
  mean that the baseline is out of date."""

  def __init__(self):
    self.failures = []
    self.notes = []

  def fail(self, message):
    self.failures.append(message)

  def note(self, message):
    self.notes.append(message)

  def note_changes(self, what, expected, actual):
    expected, actual = set(expected), set(actual)
    for item in sorted(actual - expected):
      self.note("%s %s is new." % (what, item))
    for item in sorted(expected - actual):
      self.note("%s %s is no longer used." % (what, item))


def check_symbols(report, usage, entry, cores):
  providers = entry.get("symbols", {})
  baselined = {symbol for symbols in providers.values() for symbol in symbols}
  for symbol in sorted(set(usage.symbols) - baselined):
    report.fail(
        "%s now needs %s. Find the product that provides it and add it to %s "
        "with `update`." % (usage.name, symbol, BASELINE_NAME)
    )
  report.note_changes("%s symbol" % usage.name, baselined, usage.symbols)
  needed = set(providers.get(CORE, []))
  if usage.name == "FirebaseAnalytics":
    for symbol in REQUIRED_SYMBOLS:
      if symbol not in needed:
        report.fail(
            "%s must list %s under %s in %s."
            % (usage.name, symbol, CORE, BASELINE_NAME)
        )
    needed |= set(REQUIRED_SYMBOLS)
  for core in cores:
    for arch, exports in sorted(core.exports().items()):
      for symbol in sorted(needed - exports):
        report.fail(
            "%s (%s) doesn't export %s, which %s needs. Apps that use "
            "FirebaseAnalytics would fail to link."
            % (core, arch, symbol, usage.name)
        )
      # Symbols that FirebaseCore provides, but the baseline attributes to
      # another product.
      for symbol in sorted(set(usage.symbols) & exports - needed):
        report.fail(
            "%s needs %s, which %s exports, but %s doesn't list it under %s."
            % (usage.name, symbol, core, BASELINE_NAME, CORE)
        )


def shared_selectors(usage, core_selectors):
  """Selectors that the binary uses and FirebaseCore implements."""
  return (usage.selectors & core_selectors) - NSOBJECT_SELECTORS


def check_selectors(report, usage, entry, core_selectors, contract):
  shared = shared_selectors(usage, core_selectors)
  report.note_changes(
      "%s selector" % usage.name, entry.get("selectors", []), shared
  )
  for selector in sorted(shared - contract):
    report.fail(
        "%s uses the selector %s, which FirebaseCore implements, but the "
        "runtime ABI contract in %s doesn't cover it. Add it to the contract."
        % (usage.name, selector, os.path.relpath(RUNTIME_ABI_TEST, REPO_ROOT))
    )


def check_names(report, usage, entry, cores):
  names = entry.get("names", {})
  expected_core = set(names.get(CORE, []))
  actual_core = set(core_names(usage.names, cores))
  for name in sorted(expected_core - actual_core):
    if name in usage.names:
      report.fail(
          "%s looks up the name \"%s\" at run time, but it's no longer a "
          "FirebaseCore class or protocol, or a string in FirebaseCore's "
          "sources." % (usage.name, name)
      )
  baselined = expected_core | set(names.get("other", []))
  report.note_changes("%s name" % usage.name, baselined, usage.names)
  for name in sorted(actual_core - expected_core):
    if name in baselined:
      report.note("%s name %s is now a FirebaseCore name." % (usage.name, name))
  for name in sorted(actual_core):
    if not quoted_in(CORE_CONTRACT_TEST_DIRS, name):
      report.fail(
          "%s looks up the name \"%s\", which FirebaseCore uses, but no "
          "FirebaseCore test pins it. Add it to a test in %s."
          % (
              usage.name,
              name,
              ", ".join(
                  os.path.relpath(d, REPO_ROOT) for d in CORE_CONTRACT_TEST_DIRS
              ),
          )
      )


def check_dynamic_client(report, client, symbols, cores):
  """Checks that `client` gets `symbols` from the dynamic libraries."""
  libraries = {
      os.path.splitext(os.path.basename(path))[0]
      for core in cores
      for path in core.paths
  }
  if not os.path.exists(client):
    report.fail(
        "%s doesn't exist. If the dynamic link test failed to link, the "
        "failures above say why." % client
    )
    return
  for arch in archs(client):
    bound = {}
    pattern = re.compile(
        r"^\s+\(undefined\) (?:weak )?external (\S+) \(from (\S+)\)"
    )
    for line in run(["xcrun", "nm", "-arch", arch, "-m", client]).splitlines():
      match = pattern.match(line)
      if match:
        bound[match.group(1)] = match.group(2)
    for symbol in sorted(symbols):
      library = bound.get(symbol)
      if library is None:
        report.fail(
            "%s (%s) doesn't get %s from a FirebaseCore dynamic library. A "
            "static copy of FirebaseCore was probably linked in."
            % (client, arch, symbol)
        )
      elif library not in libraries:
        report.fail(
            "%s (%s) gets %s from %s, which isn't a FirebaseCore library."
            % (client, arch, symbol, library)
        )


# ---------------------------------------------------------------------------
# Commands


def load_usages(args):
  xcframeworks = find_xcframeworks(args.workspace_state)
  return [binary_usage(name, xcframeworks[name]) for name in BINARIES]


def load_cores(args):
  return [static_core(d) for d in args.static or []] + [
      dynamic_core(d) for d in args.dynamic or []
  ]


def core_selector_set(cores):
  if not cores:
    return None
  selectors = set()
  for core in cores:
    selectors |= core.selectors()
  return selectors


def command_list(args):
  cores = load_cores(args)
  core_selectors = core_selector_set(cores)
  contract = runtime_abi_selectors()
  for usage in load_usages(args):
    print("%s (%d slices)" % (usage.name, len(usage.slice_names)))
    print("  Firebase symbols:")
    for symbol in sorted(usage.symbols):
      count = len(usage.symbols[symbol])
      total = len(usage.slice_names)
      print("    %s (%d of %d slices)" % (symbol, count, total))
    if core_selectors is not None:
      print("  Selectors that FirebaseCore implements:")
      for selector in sorted(shared_selectors(usage, core_selectors)):
        note = ""
        if selector not in contract:
          note = " (NOT IN THE RUNTIME ABI CONTRACT)"
        print("    %s%s" % (selector, note))
    names = set(core_names(usage.names, cores))
    print("  Names looked up at run time:")
    for name in sorted(usage.names):
      print("    %s%s" % (name, " (FirebaseCore)" if name in names else ""))
  return 0


def command_check(args):
  cores = load_cores(args)
  if not cores:
    raise GateError("Pass --static, --dynamic or both.")
  baseline = read_json(BASELINE)
  contract = runtime_abi_selectors()
  core_selectors = core_selector_set(cores)
  report = Report()
  core_symbols = set(REQUIRED_SYMBOLS)
  for usage in load_usages(args):
    entry = baseline.get(usage.name, {})
    check_symbols(report, usage, entry, cores)
    check_selectors(report, usage, entry, core_selectors, contract)
    check_names(report, usage, entry, cores)
    core_symbols |= set(entry.get("symbols", {}).get(CORE, []))
  if args.dynamic_client:
    if not args.dynamic:
      raise GateError("--dynamic-client needs --dynamic.")
    dynamic = [core for core in cores if core.kind == "dynamic"]
    check_dynamic_client(report, args.dynamic_client, core_symbols, dynamic)

  for core in cores:
    log("Checked %s." % core.description())
  if report.notes:
    log()
    log(
        "%s is out of date. If the binaries changed, review the changes and "
        "run `scripts/core_api/check_binary_link.py update`:" % BASELINE_NAME
    )
    for note in report.notes:
      log("  - " + note)
  if report.failures:
    log()
    log("The FirebaseCore binary link check failed:")
    for failure in report.failures:
      log("  - " + failure)
    log()
    log("See FirebaseCore/Tests/APIBaselines/README.md.")
    return 1
  log("FirebaseCore provides everything the binaries need.")
  return 0


def command_update(args):
  cores = load_cores(args)
  if not cores:
    raise GateError("Pass --static, --dynamic or both.")
  old = read_json(BASELINE) if os.path.exists(BASELINE) else {}
  core_selectors = core_selector_set(cores)
  core_paths = {path for core in cores for path in core.paths}
  others = {}
  for directory in args.static or []:
    others.update(product_exports(directory, core_paths))
  baseline = {}
  for usage in load_usages(args):
    old_entry = old.get(usage.name, {})
    providers = symbol_providers(usage, old_entry, cores, others)
    baseline[usage.name] = baseline_entry(
        usage, providers, cores, core_selectors
    )
  write_json(BASELINE, baseline)
  log("Wrote %s." % os.path.relpath(BASELINE, REPO_ROOT))
  return 0


def main():
  parser = argparse.ArgumentParser(
      description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
  )
  parser.add_argument("command", choices=["list", "check", "update"])
  parser.add_argument(
      "--workspace-state",
      default=os.path.join(REPO_ROOT, ".build", "workspace-state.json"),
      help="SwiftPM workspace state that lists the binary artifacts.",
  )
  parser.add_argument(
      "--static",
      action="append",
      help="Products directory of the root package. Can be repeated.",
  )
  parser.add_argument(
      "--dynamic",
      action="append",
      help="Products directory of scripts/core_api/binary_link. Can be "
      "repeated.",
  )
  parser.add_argument(
      "--dynamic-client",
      help="A binary that should link FirebaseCore dynamically.",
  )
  args = parser.parse_args()
  commands = {
      "list": command_list,
      "check": command_check,
      "update": command_update,
  }
  try:
    return commands[args.command](args)
  except GateError as error:
    log("error: %s" % error)
    return 2


if __name__ == "__main__":
  sys.exit(main())

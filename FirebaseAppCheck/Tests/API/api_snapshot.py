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
"""Generates normalized snapshots of the FirebaseAppCheck public API.

Two snapshots are produced from a SwiftPM build directory:

  * `swift`: the API as seen by Swift clients (`import FirebaseAppCheck`),
    synthesized with `swift-synthesize-interface`. This covers both the
    Objective-C headers (as imported by the Clang importer) and the Swift
    module.
  * `objc`: the API as seen by Objective-C clients (`@import FirebaseAppCheck;`),
    extracted from the Clang AST of the public headers and, when present, the
    generated `FirebaseAppCheck-Swift.h` header.

The snapshots are compared against the checked-in golden files in this
directory, which were generated from the Objective-C implementation of the SDK.
Any difference is a public API change.

Usage (from the repository root):

  swift build --target FirebaseAppCheckSwift
  FirebaseAppCheck/Tests/API/api_snapshot.py --check [--platform ios]
  FirebaseAppCheck/Tests/API/api_snapshot.py --negative
  FirebaseAppCheck/Tests/API/api_snapshot.py --update   # regenerate goldens
"""

import argparse
import difflib
import glob
import os
import re
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), '..', '..', '..'))
API_DIR = os.path.dirname(os.path.abspath(__file__))
PUBLIC_HEADERS = os.path.join(REPO_ROOT, 'FirebaseAppCheck', 'Sources',
                              'Public', 'FirebaseAppCheck')

# `FirebaseAppCheck` is the module that apps import. Its public API is declared in Objective-C
# headers, both in the Objective-C implementation of the SDK and in the Swift implementation,
# where the `FirebaseAppCheckSwift` module implements the declared classes with
# `@objc @implementation`. `FirebaseAppCheckSwift` must not add public API: with CocoaPods, both
# are a single module.
API_MODULES = ['FirebaseAppCheck', 'FirebaseAppCheckSwift']
SWIFT_MODULES = ['FirebaseAppCheckSwift']

# The Objective-C implementation forward-declares `FIRApp` in its headers, so
# the Clang importer prints the Objective-C name. Swift prints the Swift name.
SWIFT_TYPE_RENAMES = {r'\bFIRApp\b': 'FirebaseApp'}

# Differences from the Objective-C implementation that are approved. There are none: the Swift
# implementation of the SDK implements the same Objective-C headers. Its internal declarations
# (`FIRAppCheckInternal.h`) are in the `FirebaseAppCheck.Internal` submodule, which apps don't
# import. See `APPROVED_EXTRA_PUBLIC_HEADERS` for CocoaPods and the binary distributions.
APPROVED_SWIFT_DIFFERENCES = []
APPROVED_OBJC_DIFFERENCES = []


def run(cmd, **kwargs):
  result = subprocess.run(cmd, capture_output=True, text=True,
                          errors='replace', **kwargs)
  if result.returncode != 0:
    sys.stderr.write(' '.join(cmd) + '\n' + result.stdout + result.stderr)
    raise SystemExit(result.returncode)
  return result.stdout


def sdk_path(sdk):
  return run(['xcrun', '--sdk', sdk, '--show-sdk-path']).strip()


def is_swift_build_layout(build_dir):
  """Whether `build_dir` was produced by the `swiftbuild` build system (`.build/out`)."""
  return os.path.isdir(os.path.join(build_dir, 'Intermediates.noindex'))


def swift_modules_dir(build_dir):
  if is_swift_build_layout(build_dir):
    products = sorted(glob.glob(os.path.join(build_dir, 'Products', 'Debug*')))
    return products[0] if products else os.path.join(build_dir, 'Products', 'Debug')
  return os.path.join(build_dir, 'Modules')


def header_search_flags():
  """Header search paths of the Objective-C modules that FirebaseAppCheck depends on."""
  dirs = [
      os.path.join(REPO_ROOT, 'FirebaseCore', 'Sources', 'Public'),
      os.path.join(REPO_ROOT, 'FirebaseCore', 'Extension'),
      os.path.join(REPO_ROOT, 'FirebaseAppCheck', 'Interop', 'Public'),
      os.path.join(REPO_ROOT, 'FirebaseAppCheck', 'Sources', 'Public'),
  ]
  checkouts = os.path.join(REPO_ROOT, '.build', 'checkouts')
  dirs += sorted(glob.glob(os.path.join(checkouts, 'GoogleUtilities', '*', '*', 'Public')))
  flags = []
  for directory in dirs:
    flags += ['-Xcc', '-I' + directory]
  return flags


def module_map_flags(build_dir):
  if is_swift_build_layout(build_dir):
    module_maps = glob.glob(os.path.join(build_dir, 'Intermediates.noindex',
                                         'GeneratedModuleMaps*', '*.modulemap'))
  else:
    module_maps = glob.glob(os.path.join(build_dir, '*', 'module.modulemap'))
  # Module maps of SwiftPM targets that provide their own.
  module_maps += glob.glob(os.path.join(REPO_ROOT, 'FirebaseAppCheck', 'Sources', 'Public',
                                        'module.modulemap'))
  flags = []
  for module_map in sorted(set(module_maps)):
    # The module map of a Swift module only adds its generated header, which would shadow the
    # Swift module itself.
    name = os.path.splitext(os.path.basename(module_map))[0]
    if os.path.exists(os.path.join(swift_modules_dir(build_dir), name + '.swiftmodule')):
      continue
    flags += ['-Xcc', '-fmodule-map-file=' + module_map]
  return flags


# MARK: - Swift


def synthesize_swift_interface(build_dir, module, target, sdk):
  with tempfile.NamedTemporaryFile(suffix='.swift', delete=False) as out:
    output = out.name
  cmd = [
      'xcrun', 'swift-synthesize-interface', '-module-name', module,
      '-target', target, '-sdk', sdk_path(sdk), '-I',
      swift_modules_dir(build_dir), '-module-cache-path',
      os.path.join(tempfile.gettempdir(), 'fac-api-mc'), '-o', output
  ] + module_map_flags(build_dir) + header_search_flags()
  result = subprocess.run(cmd, capture_output=True, text=True)
  if result.returncode != 0:
    messages = result.stdout + result.stderr
    swift_module = os.path.join(swift_modules_dir(build_dir), module + '.swiftmodule')
    if 'Failed to load the module' in messages and os.path.exists(swift_module):
      if module in SWIFT_MODULES and not swift_module_supports(swift_module, target):
        # A Swift module built for another platform. The Objective-C headers, which are the
        # public API, don't need a build for the target platform.
        sys.stderr.write('Skipping %s, which was not built for %s.\n' % (module, target))
        return ''
      sys.stderr.write(messages)
      raise SystemExit('Failed to synthesize the interface of %s' % module)
    # The module doesn't exist in this build configuration.
    return ''
  with open(output) as f:
    return f.read()


def swift_module_supports(swift_module, target):
  """Whether a `.swiftmodule` (a file, or a directory with a file per target) is for `target`."""
  platform = target.split('-')[2].rstrip('0123456789.')
  if os.path.isdir(swift_module):
    return any(platform in name for name in os.listdir(swift_module))
  # A single-file module, from the native build system. It records its target triple.
  with open(swift_module, 'rb') as f:
    triples = set(re.findall(rb'-apple-([a-z]+?)(?:x)?[\d.]*(-simulator)?\x00', f.read()))
  wanted = (platform.rstrip('x').encode(), b'-simulator' if target.endswith('-simulator') else b'')
  return wanted in triples


def strip_param_names(signature):
  """Drops internal parameter names: `completion handler: T` -> `completion: T`."""

  def fix_params(params):
    depth = 0
    parts, current = [], ''
    for ch in params:
      if ch in '([<':
        depth += 1
      elif ch in ')]>':
        depth -= 1
      if ch == ',' and depth == 0:
        parts.append(current)
        current = ''
      else:
        current += ch
    if current.strip():
      parts.append(current)
    fixed = []
    for part in parts:
      part = part.strip()
      m = re.match(r'^(\w+)\s+(\w+)\s*:(.*)$', part)
      if m:
        part = '%s:%s' % (m.group(1), m.group(3))
      fixed.append(re.sub(r'\s*:\s*', ': ', part, count=1))
    return ', '.join(fixed)

  m = re.match(r'^(.*?\b(?:func\s+\w+|init[?!]?)\s*)\((.*)\)(.*)$', signature)
  if not m:
    return signature
  head, params, tail = m.groups()
  # Find the matching parenthesis of the parameter list.
  depth, end = 0, None
  text = params + ')' + tail
  for i, ch in enumerate(text):
    if ch == '(':
      depth += 1
    elif ch == ')':
      if depth == 0:
        end = i
        break
      depth -= 1
  params, tail = text[:end], text[end + 1:]
  return '%s(%s)%s' % (head, fix_params(params), tail)


SWIFT_DROPPED_ATTRIBUTES = re.compile(
    r'@objc(\([^)]*\))?\s*|@nonobjc\s*|@discardableResult\s*|'
    r'@preconcurrency\s*|@MainActor\s*|dynamic\s+|final\s+(?=class\b)')


def platform_availability(attribute, platform):
  """Keeps the parts of an `@available` attribute that apply to `platform`.

  The Clang importer only prints the availability for the platform it imports for, while Swift
  prints all platforms.
  """
  m = re.match(r'^@available\((.*)\)$', attribute)
  if not m:
    return attribute
  names = {'macos': ('macOS', 'macOSApplicationExtension'), 'ios': ('iOS',)}[platform]
  parts = [p.strip() for p in m.group(1).split(',')]
  if parts[0] in ('*',) or parts[0].split(' ')[0] not in [n for n in
                                                       ['macOS', 'iOS', 'tvOS', 'watchOS',
                                                        'visionOS', 'macCatalyst']]:
    return attribute
  kept = [p for p in parts if p.split(' ')[0] in names]
  if not kept:
    return None
  return '@available(%s, *)' % ', '.join(kept)


def normalize_swift(text, platform):
  """Returns sorted `container :: declaration` lines."""
  lines = []
  stack = []
  pending_attrs = []
  for raw in text.splitlines():
    line = raw.strip()
    if not line or line.startswith('//') or line.startswith('import ') or \
        line.startswith('@_exported import') or line.startswith('/*') or \
        line.startswith('*'):
      continue
    if line.startswith('@available') or line.startswith('@_spi'):
      pending_attrs.append(line)
      continue
    if line == '}':
      if stack:
        stack.pop()
      continue
    decl = SWIFT_DROPPED_ATTRIBUTES.sub('', line).strip()
    for pattern, replacement in SWIFT_TYPE_RENAMES.items():
      decl = re.sub(pattern, replacement, decl)
    decl = re.sub(r'\bopen\b|\bpublic\b', '', decl)
    decl = re.sub(r'\s+', ' ', decl).strip()
    opens_scope = decl.endswith('{')
    decl = decl.rstrip('{').strip()
    decl = strip_param_names(decl)
    if not decl:
      # An attribute on its own line, such as `@discardableResult`.
      continue
    attrs = ' '.join(sorted(filter(None, (platform_availability(a, platform)
                                          for a in pending_attrs))))
    pending_attrs = []
    if attrs:
      decl = attrs + ' ' + decl
    if opens_scope:
      m = re.match(r'^(.*?)(class|protocol|struct|enum|extension)\s+([\w.]+)'
                   r'\s*(?::\s*(.*))?$', decl)
      if m:
        prefix, kind, name, conformances = m.groups()
        if stack:
          name = stack[-1].split(' ', 1)[1] + '.' + name
        container = '%s %s' % (kind, name)
        lines.append(('%s%s' % (prefix, container)).strip())
        for conformance in (conformances or '').split(','):
          conformance = conformance.strip()
          if conformance:
            lines.append('%s : %s' % (container, conformance))
        stack.append(container)
        continue
      stack.append(decl)
      continue
    if stack:
      lines.append('%s :: %s' % (stack[-1], decl))
    else:
      lines.append(decl)
  # Re-declared `extension` containers of the same type are merged by keying on
  # the type name only.
  lines = [re.sub(r'^extension ', 'type ', l) for l in lines]
  lines = [re.sub(r'^(class|struct|enum|protocol) ', 'type ', l)
           if ' :: ' not in l and ' : ' not in l else l for l in lines]
  return sorted(set(lines))


def swift_snapshot(build_dir, target, sdk, platform):
  text = ''
  for module in API_MODULES:
    text += synthesize_swift_interface(build_dir, module, target, sdk) + '\n'
  return normalize_swift(text, platform)


# MARK: - Objective-C

OBJC_API_NAME = re.compile(
    r'^k?FIR(AppCheck|AppAttest|DeviceCheck|Recaptcha)\w*$')


def is_api_name(name):
  return bool(OBJC_API_NAME.match(name)) and not name.endswith('Interop')


def clean_type(text):
  text = text.replace('__strong', '')
  text = re.sub(r'\s+', ' ', text)
  text = re.sub(r'\s+([,)])', r'\1', text)
  return text.strip()


def first_quoted(line):
  m = re.search(r"'([^']*)'", line)
  return clean_type(m.group(1)) if m else ''


class Node(object):

  def __init__(self, text, depth):
    self.text = text
    self.depth = depth
    self.children = []


def parse_ast_dump(text):
  """Parses `clang -Xclang -ast-dump` output into trees of `Node`s."""
  roots = []
  stack = []
  for line in text.splitlines():
    if not line.strip() or line.startswith('Dumping '):
      continue
    m = re.match(r'^([ |`-]*)(.*)$', line)
    prefix, content = m.groups()
    depth = len(prefix) // 2
    node = Node(content, depth)
    while stack and stack[-1].depth >= depth:
      stack.pop()
    if stack:
      stack[-1].children.append(node)
    else:
      roots.append(node)
    stack.append(node)
  return roots


def attribute_text(node, include_swift_name):
  text = node.text
  kind = text.split(' ', 1)[0]
  if kind == 'AvailabilityAttr':
    m = re.search(r'> (\w+) ([\d.]+) ([\d.]+) ([\d.]+) "([^"]*)" "([^"]*)" '
                  r'(\d+)', text)
    if m:
      platform, introduced, deprecated, obsoleted = m.groups()[:4]
      unavailable = ' unavailable' in text.split('>', 1)[-1].split('"')[0]
      return 'API_AVAILABLE(%s %s%s)' % (
          platform, introduced, ' deprecated=' + deprecated
          if deprecated not in ('0', '') else '')
    m = re.search(r'> (\w+) 0 0 0 Unavailable', text)
    if m:
      return 'API_UNAVAILABLE(%s)' % m.group(1)
    return 'AVAILABILITY(%s)' % text.split('>', 1)[-1].strip()
  if kind == 'UnavailableAttr':
    return 'UNAVAILABLE'
  if kind == 'DeprecatedAttr':
    return 'DEPRECATED'
  if kind == 'SwiftNameAttr' and include_swift_name:
    m = re.search(r'"([^"]*)"\s*$', text)
    return 'NS_SWIFT_NAME(%s)' % (m.group(1) if m else '')
  return None


def attributes(node, include_swift_name=False):
  result = []
  for child in node.children:
    attr = attribute_text(child, include_swift_name)
    if attr:
      result.append(attr)
  return sorted(set(result))


def format_objc_method(node):
  m = re.search(r" ([-+]) (\S+) '", node.text)
  sign, selector = m.groups()
  return_type = first_quoted(node.text[m.end() - 1:])
  params = [first_quoted(c.text) for c in node.children
            if c.text.startswith('ParmVarDecl')]
  pieces = selector.split(':')
  if params:
    signature = ' '.join('%s:(%s)' % (piece, param)
                         for piece, param in zip(pieces, params))
  else:
    signature = selector
  return '%s (%s)%s' % (sign, return_type, signature)


def objc_container_lines(node, container, lines):
  for child in node.children:
    text = child.text
    if text.startswith('super ObjCInterface'):
      lines.add('%s : %s' % (container, first_quoted(text)))
    elif text.startswith('ObjCProtocol '):
      lines.add('%s <%s>' % (container, first_quoted(text)))
    elif text.startswith('ObjCMethodDecl'):
      if ' implicit ' in text:
        continue
      lines.add(' '.join([container, format_objc_method(child)] +
                         attributes(child)))
    elif text.startswith('ObjCPropertyDecl'):
      m = re.search(r" (\w+) '", text)
      name = m.group(1)
      flags = text.rsplit("'", 1)[-1].split()
      flags = [f for f in flags if f not in ('unsafe_unretained', 'strong',
                                             'atomic')]
      lines.add(' '.join(['%s @property(%s) %s %s' % (
          container, ','.join(sorted(flags)), first_quoted(text), name)] +
                         attributes(child)))
  for attr in attributes(node, include_swift_name=True):
    lines.add('%s %s' % (container, attr))


def objc_decl_lines(node, lines):
  text = node.text
  kind = text.split(' ', 1)[0]
  if kind in ('ObjCInterfaceDecl', 'ObjCProtocolDecl'):
    name = text.rsplit(' ', 1)[-1]
    if not is_api_name(name) or not node.children:
      return
    keyword = '@interface' if kind == 'ObjCInterfaceDecl' else '@protocol'
    objc_container_lines(node, '%s %s' % (keyword, name), lines)
  elif kind == 'ObjCCategoryDecl':
    for child in node.children:
      if child.text.startswith('ObjCInterface '):
        name = first_quoted(child.text)
        if is_api_name(name):
          objc_container_lines(node, '@interface %s' % name, lines)
  elif kind == 'VarDecl':
    m = re.search(r" (\w+) '", text)
    if m and is_api_name(m.group(1)):
      lines.add(' '.join(['extern %s %s' % (first_quoted(text), m.group(1))] +
                         attributes(node, include_swift_name=True)))
  elif kind == 'TypedefDecl':
    m = re.search(r" (\w+) '", text)
    if m and is_api_name(m.group(1)):
      lines.add('typedef %s %s' % (first_quoted(text), m.group(1)))
  elif kind == 'EnumDecl':
    m = re.search(r" (\w+) '", text)
    if not m or not is_api_name(m.group(1)):
      return
    name = m.group(1)
    for attr in attributes(node, include_swift_name=True):
      lines.add('enum %s %s' % (name, attr))
    for child in node.children:
      if child.text.startswith('NSErrorDomainAttr'):
        lines.add('enum %s NS_ERROR_ENUM(%s)' %
                  (name, child.text.rsplit(' ', 1)[-1]))
      if not child.text.startswith('EnumConstantDecl'):
        continue
      constant = re.search(r" (\w+) '", child.text).group(1)
      value = ''
      stack = list(child.children)
      while stack:
        grandchild = stack.pop()
        vm = re.match(r'value: Int (-?\d+)', grandchild.text)
        if vm:
          value = vm.group(1)
        stack.extend(grandchild.children)
      lines.add('enum %s %s = %s' % (name, constant, value))


def clang_command(sdk, target, include_dirs, extra):
  cmd = ['xcrun', 'clang', '-x', 'objective-c', '-fobjc-arc', '-fno-modules',
         '-isysroot', sdk_path(sdk), '-target', target, '-Wno-everything',
         '-fno-color-diagnostics'] + extra
  for include_dir in include_dirs:
    cmd += ['-I', include_dir]
  return cmd


def write_tu(source):
  with tempfile.NamedTemporaryFile(suffix='.m', mode='w', delete=False) as tu:
    tu.write(source)
    return tu.name


def objc_ast(source, include_dirs, sdk, target):
  cmd = clang_command(sdk, target, include_dirs, [
      '-fsyntax-only', '-Xclang', '-ast-dump', '-Xclang',
      '-ast-dump-filter=FIR'
  ])
  return run(cmd + [write_tu(source)])


def objc_macros(source, include_dirs, sdk, target):
  cmd = clang_command(sdk, target, include_dirs, ['-E', '-dM'])
  macros = set()
  for line in run(cmd + [write_tu(source)]).splitlines():
    m = re.match(r'#define (FIR_\w+)(.*)$', line)
    if m:
      macros.add('#define %s %s' % (m.group(1), m.group(2).strip()))
  return macros


def generated_swift_headers(build_dir):
  """Returns the generated Objective-C headers of the Swift modules of the SDK."""
  headers = []
  for module in SWIFT_MODULES:
    candidates = glob.glob(os.path.join(build_dir, module + '.build', 'include',
                                        module + '-Swift.h'))
    candidates += glob.glob(os.path.join(build_dir, 'Intermediates.noindex',
                                         'GeneratedModuleMaps*', module + '-Swift.h'))
    headers += candidates[:1]
  return headers


def objc_snapshot(build_dir, target, sdk):
  include_dirs = [
      os.path.join(REPO_ROOT, 'FirebaseCore', 'Sources', 'Public'),
      os.path.join(REPO_ROOT, 'FirebaseAppCheck', 'Interop', 'Public'),
      os.path.join(REPO_ROOT, 'FirebaseAppCheck', 'Sources', 'Public'),
  ]
  source = ('#import <Foundation/Foundation.h>\n'
            '#import <FirebaseCore/FirebaseCore.h>\n'
            '#import <FirebaseAppCheckInterop/FirebaseAppCheckInterop.h>\n'
            '#import <FirebaseAppCheck/FirebaseAppCheck.h>\n')
  for swift_header in generated_swift_headers(build_dir):
    source += '#import "%s"\n' % swift_header
  lines = set()
  for root in parse_ast_dump(objc_ast(source, include_dirs, sdk, target)):
    objc_decl_lines(root, lines)
  lines |= objc_macros(source, include_dirs, sdk, target)
  # Clang makes `+new` unavailable when `-init` is unavailable, so the explicit declaration in
  # the generated Swift header doesn't change the API.
  for line in list(lines):
    m = re.match(r'^(@interface \w+) \+ \(instancetype _Nonnull\)new UNAVAILABLE$', line)
    if m and '%s - (instancetype _Nonnull)init UNAVAILABLE' % m.group(1) in lines:
      lines.remove(line)
  return sorted(lines)


# MARK: - Negative compile tests

# Each snippet must fail to compile: these APIs are unavailable, or internal.
NEGATIVE_SWIFT_SNIPPETS = [
    '_ = AppCheck()',
    '_ = AppCheckToken()',
    '_ = AppCheckDebugProvider()',
    '_ = AppCheck(app: FirebaseApp.app()!)',
    'AppCheck.appCheck().tokenDidUpdate',
    'if #available(watchOS 9.0, *) { _ = DeviceCheckProvider() }',
    'if #available(macOS 11.3, watchOS 9.0, *) { _ = AppAttestProvider() }',
]
NEGATIVE_SWIFT_SNIPPETS_IOS = [
    '_ = RecaptchaProvider()',
    '_ = RecaptchaProviderFactory()',
]
NEGATIVE_OBJC_SNIPPETS = [
    '(void)[[FIRAppCheck alloc] init];',
    '(void)[FIRAppCheck new];',
    '(void)[[FIRAppCheckToken alloc] init];',
    '(void)[[FIRAppCheckDebugProvider alloc] init];',
    '(void)[FIRAppCheckDebugProvider new];',
]
NEGATIVE_OBJC_SNIPPETS_IOS = [
    '(void)[[FIRRecaptchaProviderFactory alloc] init];',
    '(void)[[FIRRecaptchaProvider alloc] init];',
]
# A snippet that must compile, to verify that the compiler invocations are correct.
POSITIVE_SWIFT_SNIPPET = '_ = AppCheckToken(token: "", expirationDate: Date())'
POSITIVE_OBJC_SNIPPET = (
    '(void)[[FIRAppCheckToken alloc] initWithToken:@"" expirationDate:[NSDate date]];'
    ' (void)[FIRAppCheck appCheck];')


def swift_compiles(build_dir, target, sdk, snippet):
  with tempfile.NamedTemporaryFile(suffix='.swift', mode='w', delete=False) as f:
    f.write('import FirebaseAppCheck\nimport FirebaseCore\nimport Foundation\n'
            'func test() {\n  %s\n}\n' % snippet)
    path = f.name
  cmd = ['xcrun', 'swiftc', '-typecheck', '-target', target, '-sdk', sdk_path(sdk),
         '-I', swift_modules_dir(build_dir), '-module-cache-path',
         os.path.join(tempfile.gettempdir(), 'fac-api-mc'), path]
  cmd += module_map_flags(build_dir) + header_search_flags()
  return subprocess.run(cmd, capture_output=True, text=True).returncode == 0


def objc_compiles(build_dir, target, sdk, snippet):
  with tempfile.NamedTemporaryFile(suffix='.m', mode='w', delete=False) as f:
    f.write('@import FirebaseAppCheck;\n@import FirebaseCore;\n'
            'void test(void) {\n  %s\n}\n' % snippet)
    path = f.name
  if is_swift_build_layout(build_dir):
    module_maps = glob.glob(os.path.join(build_dir, 'Intermediates.noindex',
                                         'GeneratedModuleMaps*', '*.modulemap'))
  else:
    module_maps = glob.glob(os.path.join(build_dir, '*', 'module.modulemap'))
  cmd = ['xcrun', 'clang', '-x', 'objective-c', '-fobjc-arc', '-fmodules', '-fsyntax-only',
         '-isysroot', sdk_path(sdk), '-target', target, '-fmodules-cache-path=' +
         os.path.join(tempfile.gettempdir(), 'fac-api-mc'), path]
  cmd += ['-fmodule-map-file=' + m for m in module_maps]
  cmd += [flag for flag in header_search_flags() if flag != '-Xcc']
  return subprocess.run(cmd, capture_output=True, text=True).returncode == 0


def negative_compile_tests(build_dir, target, sdk, platform):
  ok = True
  checks = [(swift_compiles, POSITIVE_SWIFT_SNIPPET, True),
            (objc_compiles, POSITIVE_OBJC_SNIPPET, True)]
  swift_snippets = NEGATIVE_SWIFT_SNIPPETS + (
      NEGATIVE_SWIFT_SNIPPETS_IOS if platform == 'ios' else [])
  objc_snippets = NEGATIVE_OBJC_SNIPPETS + (
      NEGATIVE_OBJC_SNIPPETS_IOS if platform == 'ios' else [])
  checks += [(swift_compiles, snippet, False) for snippet in swift_snippets]
  checks += [(objc_compiles, snippet, False) for snippet in objc_snippets]
  for compiles, snippet, expected in checks:
    actual = compiles(build_dir, target, sdk, snippet)
    language = 'Swift' if compiles is swift_compiles else 'Objective-C'
    if actual != expected:
      ok = False
      print('FAIL (%s): `%s` %s' % (language, snippet,
                                     'compiles' if actual else 'does not compile'))
  print('Negative compile tests (%s): %s' % (platform, 'passed' if ok else 'FAILED'))
  return ok


# MARK: - Main

PLATFORMS = {
    'macos': ('arm64-apple-macos14.0', 'macosx'),
    'ios': ('arm64-apple-ios15.0-simulator', 'iphonesimulator'),
}


def golden_path(kind, platform):
  return os.path.join(API_DIR, '%s_api_%s.txt' % (kind, platform))


# Headers in the public headers directory that `FirebaseAppCheck.h` doesn't import. With SwiftPM,
# `FIRAppCheckInternal.h` is only in the explicit submodule `FirebaseAppCheck.Internal`. CocoaPods
# (used for internal testing only since Firebase 13) and the binary distributions built from the
# podspec make it a public header, so apps that use them can see its declarations. They aren't
# public API.
APPROVED_EXTRA_PUBLIC_HEADERS = {'FIRAppCheckInternal.h'}


def check_public_headers():
  """Checks that every public header is part of the umbrella header `FirebaseAppCheck.h`.

  The snapshots above cover the SwiftPM module, whose umbrella header is `FirebaseAppCheck.h`.
  CocoaPods instead generates an umbrella header that imports every header in the public headers
  directory, and the frameworks built from the podspec also ship all of them. A header there that
  `FirebaseAppCheck.h` doesn't import, directly or indirectly, adds API with CocoaPods and the
  binary distributions only.
  """

  def imports(header):
    with open(os.path.join(PUBLIC_HEADERS, header), encoding='utf-8') as f:
      return set(re.findall(r'^\s*#import\s+"([^"]+)"', f.read(), re.MULTILINE))

  reachable, pending = set(), ['FirebaseAppCheck.h']
  while pending:
    header = pending.pop()
    if header in reachable:
      continue
    reachable.add(header)
    pending.extend(imports(header))
  headers = {os.path.basename(h) for h in glob.glob(os.path.join(PUBLIC_HEADERS, '*.h'))}
  extra = headers - reachable
  ok = True
  if extra - APPROVED_EXTRA_PUBLIC_HEADERS:
    print('Public headers that FirebaseAppCheck.h does not import: %s' %
          ', '.join(sorted(extra - APPROVED_EXTRA_PUBLIC_HEADERS)))
    ok = False
  if APPROVED_EXTRA_PUBLIC_HEADERS - extra:
    print('Approved extra public headers that are missing or imported by FirebaseAppCheck.h: %s' %
          ', '.join(sorted(APPROVED_EXTRA_PUBLIC_HEADERS - extra)))
    ok = False
  if ok:
    print('Public headers: no changes')
  return ok


def diff(kind, platform, actual, approved):
  with open(golden_path(kind, platform)) as f:
    expected = [l.rstrip('\n') for l in f if l.strip()]
  actual = [l for l in actual if l not in approved]
  if expected == actual:
    print('%s API (%s): no changes' % (kind, platform))
    return True
  sys.stdout.writelines(
      difflib.unified_diff([l + '\n' for l in expected],
                           [l + '\n' for l in actual],
                           fromfile='golden', tofile='current'))
  return False


def resolve_build_dir(path):
  """Returns the build directory in a SwiftPM scratch path (`.build`) or build directory.

  The `swiftbuild` build system builds into `<scratch path>/out`, and the native build system into
  `<scratch path>/<triple>/debug`, with a `<scratch path>/debug` symlink.
  """
  candidates = [os.path.join(path, 'out'), os.path.join(path, 'debug')]
  candidates += sorted(glob.glob(os.path.join(path, '*-apple-*', 'debug')))
  for candidate in candidates:
    if os.path.isdir(candidate):
      return os.path.realpath(candidate)
  return os.path.realpath(path)


def default_build_dir():
  """Returns the build directory of `swift build` in the repository, for either build system."""
  return resolve_build_dir(os.path.join(REPO_ROOT, '.build'))


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--build-dir', default=default_build_dir(), type=resolve_build_dir,
                      help='The SwiftPM scratch path (such as `.build`) or build directory. '
                      'Build the `FirebaseAppCheckSwift` target first.')
  parser.add_argument('--platform', choices=sorted(PLATFORMS), default='macos')
  group = parser.add_mutually_exclusive_group(required=True)
  group.add_argument('--check', action='store_true')
  group.add_argument('--update', action='store_true')
  group.add_argument('--print', choices=['swift', 'objc'])
  group.add_argument('--negative', action='store_true',
                     help='Run the negative compile tests.')
  args = parser.parse_args()

  target, sdk = PLATFORMS[args.platform]
  snapshots = {
      'swift': (lambda: swift_snapshot(args.build_dir, target, sdk, args.platform),
                APPROVED_SWIFT_DIFFERENCES),
      'objc': (lambda: objc_snapshot(args.build_dir, target, sdk),
               APPROVED_OBJC_DIFFERENCES),
  }
  if args.negative:
    return 0 if negative_compile_tests(args.build_dir, target, sdk, args.platform) else 1
  if args.print:
    print('\n'.join(snapshots[args.print][0]()))
    return 0
  ok = True
  if args.check:
    ok = check_public_headers()
  for kind, (snapshot, approved) in snapshots.items():
    lines = snapshot()
    if args.update:
      with open(golden_path(kind, args.platform), 'w') as f:
        f.write('\n'.join(lines) + '\n')
      print('Wrote %s' % golden_path(kind, args.platform))
    else:
      ok = diff(kind, args.platform, lines, approved) and ok
  return 0 if ok else 1


if __name__ == '__main__':
  sys.exit(main())

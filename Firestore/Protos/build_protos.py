#! /usr/bin/env python

# Copyright 2018 Google Inc. All rights reserved.
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

"""Generates and massages protocol buffer outputs.
"""

from __future__ import print_function

import sys

import argparse
import os
import os.path
import re
import shutil
import subprocess
import tarfile
import urllib2


CPP_GENERATOR = 'nanopb_cpp_generator.py'


COPYRIGHT_NOTICE = '''
/*
 * Copyright 2018 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
'''.lstrip()


def main():
  parser = argparse.ArgumentParser(
      description='Generates proto messages.')
  parser.add_argument(
      '--nanopb', action='store_true',
      help='Generates nanopb messages.')
  parser.add_argument(
      '--cpp', action='store_true',
      help='Generates C++ libprotobuf messages.')
  parser.add_argument(
      '--objc', action='store_true',
      help='Generates Objective-C messages.')
  parser.add_argument(
      '--protos-dir', dest='protos_dir',
      help='Source directory containing .proto files.')
  parser.add_argument(
      '--output-dir', '-d', dest='output_dir',
      help='Directory to write files; subdirectories will be created.')

  parser.add_argument(
      '--protoc', default='protoc',
      help='Location of the protoc executable')
  parser.add_argument(
      '--pythonpath', dest='pythonpath',
      help='Location of the protoc python library.')
  parser.add_argument(
      '--include', '-I', dest='include', action='append', default=[],
      help='Adds INCLUDE to the proto path.')
  parser.add_argument(
      '--protoc-gen-grpc', dest='protoc_gen_grpc',
      help='Location of the gRPC generator executable.')

  if len(sys.argv) == 1:
    parser.print_help()
    sys.exit(1)
  args = parser.parse_args()

  if args.protos_dir is None:
    root_dir = os.path.abspath(os.path.dirname(__file__))
    args.protos_dir = os.path.join(root_dir, 'protos')

  if args.output_dir is None:
    args.output_dir = os.getcwd()

  nanopb_proto_files = collect_files(args.protos_dir, '.proto')

  if args.nanopb:
    NanopbGenerator(args, nanopb_proto_files).run()

  proto_files = remove_well_known_protos(nanopb_proto_files)
  if args.cpp:
    CppProtobufGenerator(args, proto_files).run()

  if args.objc:
    ObjcProtobufGenerator(args, proto_files).run()


class NanopbGenerator(object):
  """Builds and runs the nanopb plugin to protoc."""

  def __init__(self, args, proto_files):
    self.args = args
    self.proto_files = proto_files

  def run(self):
    """Performs the action of the the generator."""

    nanopb_out = os.path.join(self.args.output_dir, 'nanopb')
    mkdir(nanopb_out)

    self.__run_generator(nanopb_out)

    sources = collect_files(nanopb_out, '.nanopb.h', '.nanopb.c')
    post_process_files(sources, add_copyright, nanopb_rename_delete)

  def __run_generator(self, out_dir):
    """Invokes protoc using the nanopb plugin."""
    cmd = protoc_command(self.args)

    gen = os.path.join(os.path.dirname(__file__), CPP_GENERATOR)
    cmd.append('--plugin=protoc-gen-nanopb=%s' % gen)

    nanopb_flags = ' '.join([
        '--extension=.nanopb',
        '--options-file=%s/%%s.options' % self.args.protos_dir,
        '--no-timestamp',
    ])
    cmd.append('--nanopb_out=%s:%s' % (nanopb_flags, out_dir))

    cmd.extend(self.proto_files)
    run_protoc(self.args, cmd)


class ObjcProtobufGenerator(object):
  """Runs protoc for Objective-C."""

  def __init__(self, args, proto_files):
    self.args = args
    self.proto_files = proto_files

  def run(self):
    objc_out = os.path.join(self.args.output_dir, 'objc')
    mkdir(objc_out)

    self.__run_generator(objc_out)
    self.__stub_non_buildable_files(objc_out)

    sources = collect_files(objc_out, '.h', '.m')
    post_process_files(
        sources,
        add_copyright,
        strip_trailing_whitespace,
        objc_flatten_imports,
        objc_strip_extension_registry
    )

  def __run_generator(self, out_dir):
    """Invokes protoc using the objc and grpc plugins."""
    cmd = protoc_command(self.args)

    gen = self.args.protoc_gen_grpc
    if gen is not None:
      cmd.append('--plugin=protoc-gen-grpc=%s' % gen)

    cmd.extend(['--objc_out=' + out_dir, '--grpc_out=' + out_dir])
    cmd.extend(self.proto_files)
    run_protoc(self.args, cmd)

  def __stub_non_buildable_files(self, out_dir):
    """Stub out generated files that make no sense."""

    write_file(os.path.join(out_dir, 'google/api/Annotations.pbobjc.m'), [
        'static int annotations_stub  __attribute__((unused,used)) = 0;\n'
    ])

    write_file(os.path.join(out_dir, 'google/api/Annotations.pbobjc.h'), [
        '// Empty stub file\n'
    ])


class CppProtobufGenerator(object):
  """Runs protoc for C++ libprotobuf (used in testing)."""

  def __init__(self, args, proto_files):
    self.args = args
    self.proto_files = proto_files

  def run(self):
    out_dir = os.path.join(self.args.output_dir, 'cpp')
    mkdir(out_dir)

    self.__run_generator(out_dir)

    sources = collect_files(out_dir, '.pb.h', '.pb.cc')
    # TODO(wilhuff): strip trailing whitespace?
    post_process_files(
        sources,
        add_copyright
    )

  def __run_generator(self, out_dir):
    """Invokes protoc using using the default C++ generator."""

    cmd = protoc_command(self.args)
    cmd.append('--cpp_out=' + out_dir)
    cmd.extend(self.proto_files)

    run_protoc(self.args, cmd)


def protoc_command(args):
  """Composes the initial protoc command-line including its include path."""
  cmd = [args.protoc]
  if args.include is not None:
    cmd.extend(['-I%s' % path for path in args.include])
  return cmd


def run_protoc(args, cmd):
  kwargs={}
  if args.pythonpath:
    env = os.environ.copy()
    env['PYTHONPATH'] = args.pythonpath
    kwargs['env'] = env

  subprocess.check_call(cmd, **kwargs)


def remove_well_known_protos(filenames):
  """Remove "well-known" protos for objc and cpp.

  On those platforms we get these for free as a part of the protobuf runtime.
  We only need them for nanopb.

  Args:
    filenames: A list of filenames, each naming a .proto file.

  Returns:
    The filenames with members of google/protobuf removed.
  """

  return [f for f in filenames if 'protos/google/protobuf/' not in f]


def post_process_files(filenames, *processors):
  for filename in filenames:
    lines = []
    with open(filename, 'r') as fd:
      lines = fd.readlines()

    for processor in processors:
      lines = processor(lines)

    write_file(filename, lines)


def write_file(filename, lines):
  with open(filename, 'w') as fd:
    fd.write(''.join(lines))


def add_copyright(lines):
  """Adds a copyright notice to the lines."""
  result = [COPYRIGHT_NOTICE, '\n']
  result.extend(lines)
  return result


def nanopb_rename_delete(lines):
  """Renames a delete symbol to delete_.

  If a proto uses a field named 'delete', nanopb happily uses that in the
  message definition. Works fine for C; not so much for C++.

  Args:
    lines: The lines to fix.

  Returns:
    The lines, fixed.
  """
  delete_keyword = re.compile(r'\bdelete\b')
  return [delete_keyword.sub('delete_', line) for line in lines]


def strip_trailing_whitespace(lines):
  """Removes trailing whitespace from the given lines."""
  return [line.rstrip() + '\n' for line in lines]


def objc_flatten_imports(lines):
  """Flattens the import statements for compatibility with CocoaPods."""

  long_import = re.compile(r'#import ".*/')
  return [long_import.sub('#import "', line) for line in lines]


def objc_strip_extension_registry(lines):
  """Removes extensionRegistry methods from the classes."""

  skip = False
  result = []
  for line in lines:
    if '+ (GPBExtensionRegistry*)extensionRegistry {' in line:
      skip = True
    if not skip:
      result.append(line)
    elif line == '}\n':
      skip = False

  return result


def collect_files(root_dir, *extensions):
  """Finds files with the given extensions in the root_dir."""
  result = []
  for root, dirs, files in os.walk(root_dir):
    del dirs
    for basename in files:
      for ext in extensions:
        if basename.endswith(ext):
          filename = os.path.join(root, basename)
          result.append(filename)
  return result


def mkdir(dirname):
  if not os.path.isdir(dirname):
    os.makedirs(dirname)


if __name__ == '__main__':
  main()

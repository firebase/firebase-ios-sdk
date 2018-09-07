#! /usr/bin/env python

# Copyright 2018 Google
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
import subprocess


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
      '--protos-dir', dest='protos_dir',
      help='Source directory containing .proto files.')
  parser.add_argument(
      '--output-dir', '-d', dest='output_dir',
      help='Directory to write files; subdirectories will be created.')

  parser.add_argument(
      '--protoc', default='protoc',
      help='Location of the protoc executable')
  parser.add_argument(
      '--pythonpath',
      help='Location of the protoc python library.')
  parser.add_argument(
      '--include', '-I', action='append', default=[],
      help='Adds INCLUDE to the proto path.')
  parser.add_argument(
      '--protoc-gen-nanopb', dest='protoc_gen_nanopb',
      help='Location of the nanopb generator executable.')

  args = parser.parse_args()
  if args.nanopb is None:
    parser.print_help()
    sys.exit(1)

  if args.protos_dir is None:
    root_dir = os.path.abspath(os.path.dirname(__file__))
    args.protos_dir = os.path.join(root_dir, 'protos')

  if args.output_dir is None:
    args.output_dir = os.getcwd()

  nanopb_proto_files = collect_files(args.protos_dir, '.proto')

  if args.nanopb:
    NanopbGenerator(args, nanopb_proto_files).run()


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
    cmd = [self.args.protoc]

    include = self.args.include
    if include is not None:
      for path in include:
        cmd.append('-I%s' % path)

    gen = self.args.protoc_gen_nanopb
    if gen is not None:
      cmd.append('--plugin=protoc-gen-nanopb=%s' % gen)

    nanopb_flags = ' '.join([
        '--extension=.nanopb',
        '--options-file=%s/%%s.options' % self.args.protos_dir,
        '--no-timestamp',
    ])
    cmd.append('--nanopb_out=%s:%s' % (nanopb_flags, out_dir))

    cmd.extend(self.proto_files)

    kwargs = {}
    if self.args.pythonpath:
      env = os.environ.copy()
      old_path = env.get('PYTHONPATH')
      env['PYTHONPATH'] = self.args.pythonpath
      if old_path is not None:
        env['PYTHONPATH'] += os.pathsep + old_path
      kwargs['env'] = env

    subprocess.check_call(cmd, **kwargs)


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


def collect_files(root_dir, *extensions):
  """Finds files with the given extensions in the root_dir.

  Args:
    root_dir: The directory from which to start traversing.
    *extensions: Filename extensions (including the leading dot) to find.

  Returns:
    A list of filenames, all starting with root_dir, that have one of the given
    extensions.
  """
  result = []
  for root, dirs, files in os.walk(root_dir):
    del dirs  # unused
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

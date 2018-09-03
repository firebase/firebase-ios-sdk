#! /usr/bin/python

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


NANOPB_VERSION = '0.3.8'
PROTOC_BIN = 'Pods/!ProtoCompiler/protoc'

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
      '--nanopb', action='store_true', help='Generates nanopb messages.')

  if len(sys.argv) == 1:
    parser.print_help()
    sys.exit(1)
  args = parser.parse_args()

  root_dir = os.path.dirname(__file__)
  os.chdir(root_dir)

  nanopb_proto_files = collect_files('protos', '.proto')

  if args.nanopb:
    NanopbGenerator(nanopb_proto_files).run()


class NanopbGenerator(object):
  """Builds and runs the nanopb plugin to protoc."""

  def __init__(self, proto_files):
    self.proto_files = proto_files

  def run(self):
    """Performs the action of the the generator."""

    # Must match the directory structure inside the tarball
    nanopb_dir = 'nanopb-' + NANOPB_VERSION
    generator_bin = os.path.join(nanopb_dir, 'generator/protoc-gen-nanopb')
    nanopb_out = 'nanopb'

    nanopb_py = os.path.join(nanopb_dir, 'generator/proto/nanopb_pb2.py')
    if not os.path.isfile(nanopb_py):
      self.__download()
      self.__build(nanopb_dir)

    self.__run_generator(generator_bin, nanopb_out)

    sources = collect_files(nanopb_out, '.nanopb.h', '.nanopb.c')
    post_process_files(sources, add_copyright, nanopb_rename_delete)

  def __download(self):
    """Downloads and unpacks nanopb sources."""

    url = 'https://github.com/nanopb/nanopb/archive/%s.tar.gz' % NANOPB_VERSION
    tgz = 'nanopb-%s.tar.gz' % NANOPB_VERSION

    if not os.path.isfile(tgz):
      print('Downloading %s' % url)
      response = urllib2.urlopen(url)
      with open(tgz, 'wb') as fd:
        shutil.copyfileobj(response, fd)

    with tarfile.open(tgz) as tar:
      tar.extractall()

  def __build(self, nanopb_dir):
    """Builds the nanopb plugin from sources."""

    print('Building %s' % nanopb_dir)
    cwd = os.getcwd()
    os.chdir(nanopb_dir)

    subprocess.call(['cmake', '.'])
    subprocess.call(['make'])

    # Copy built files into place where the generator expects to find them
    for src in ['plugin_pb2.py', 'nanopb_pb2.py']:
      dest = os.path.join('generator/proto', src)
      shutil.copyfile(src, dest)

    os.chdir(cwd)

  def __run_generator(self, generator_bin, out_dir):
    """Invokes protoc using the nanopb plugin."""
    nanopb_flags = ' '.join([
        '--extension=.nanopb',
        '--options-file=protos/%s.options',
    ])

    cmd = [
        PROTOC_BIN,
        '-I', 'protos',
        '--plugin=' + generator_bin,
        '--nanopb_out=%s:%s' % (nanopb_flags, out_dir),
    ]
    cmd.extend(self.proto_files)

    subprocess.call(cmd)


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


if __name__ == '__main__':
  main()

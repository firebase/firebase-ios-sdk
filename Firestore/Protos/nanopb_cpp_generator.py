#!/usr/bin/env python

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

import io
import itertools
import os
import os.path

import nanopb_generator as nanopb

import google.protobuf.text_format as text_format
from google.protobuf.descriptor_pb2 import DescriptorProto, EnumDescriptorProto, FieldDescriptorProto

# The plugin_pb2 package loads descriptors on import, but doesn't defend
# against multiple imports. Reuse the plugin package as loaded by the
# nanopb_generator.
plugin_pb2 = nanopb.plugin_pb2


def main():
  # Parse request
  if sys.platform == 'win32':
    import msvcrt
    # Set stdin and stdout to binary mode
    msvcrt.setmode(sys.stdin.fileno(), os.O_BINARY)
    msvcrt.setmode(sys.stdout.fileno(), os.O_BINARY)

  data = io.open(sys.stdin.fileno(), 'rb').read()
  request = plugin_pb2.CodeGeneratorRequest.FromString(data)

  # Generate code
  options = nanopb_parse_options(request)
  other_files = nanopb_parse_files(request, options)
  results = nanopb_generate(request, options, other_files)

  response = plugin_pb2.CodeGeneratorResponse()
  nanopb_write(results, response)

  # Write to stdout
  io.open(sys.stdout.fileno(), "wb").write(response.SerializeToString())


def nanopb_parse_options(request):
  import shlex
  args = shlex.split(request.parameter)
  options, dummy = nanopb.optparser.parse_args(args)

  # Force certain options
  options.extension = '.nanopb'

  # Replicate options setup from nanopb_generator.main_plugin.
  nanopb.Globals.verbose_options = options.verbose

  # Google's protoc does not currently indicate the full path of proto files.
  # Instead always add the main file path to the search dirs, that works for
  # the common case.
  options.options_path.append(os.path.dirname(request.file_to_generate[0]))

  return options


def nanopb_parse_files(request, options):
  # Process any include files first, in order to have them
  # available as dependencies
  other_files = {}
  for fdesc in request.proto_file:
    other_files[fdesc.name] = nanopb.parse_file(fdesc.name, fdesc, options)

  return other_files


def nanopb_generate(request, options, other_files):
  output = []

  for filename in request.file_to_generate:
    for fdesc in request.proto_file:
      if fdesc.name == filename:
        results = nanopb.process_file(filename, fdesc, options, other_files)
        output.append(results)

  return output


def nanopb_write(results, response):
  for result in results:
    f = response.file.add()
    f.name = result['headername']
    f.content = result['headerdata']

    f = response.file.add()
    f.name = result['sourcename']
    f.content = result['sourcedata']


if __name__ == '__main__':
  main()

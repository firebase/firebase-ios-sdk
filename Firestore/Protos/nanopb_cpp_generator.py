#!/usr/bin/env python

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

import io
import nanopb_generator as nanopb
import os
import os.path
import re
import shlex
import textwrap

from google.protobuf.descriptor_pb2 import FieldDescriptorProto
from lib import pretty_printing as printing

if sys.platform == 'win32':
  import msvcrt  # pylint: disable=g-import-not-at-top

# The plugin_pb2 package loads descriptors on import, but doesn't defend
# against multiple imports. Reuse the plugin package as loaded by the
# nanopb_generator.
plugin_pb2 = nanopb.plugin_pb2
nanopb_pb2 = nanopb.nanopb_pb2


def main():
  # Parse request
  if sys.platform == 'win32':
    # Set stdin and stdout to binary mode
    msvcrt.setmode(sys.stdin.fileno(), os.O_BINARY)
    msvcrt.setmode(sys.stdout.fileno(), os.O_BINARY)

  data = io.open(sys.stdin.fileno(), 'rb').read()
  request = plugin_pb2.CodeGeneratorRequest.FromString(data)

  # Preprocess inputs, changing types and nanopb defaults
  use_anonymous_oneof(request)
  use_bytes_for_strings(request)
  use_malloc(request)

  # Generate code
  options = nanopb_parse_options(request)
  parsed_files = nanopb_parse_files(request, options)
  results = nanopb_generate(request, options, parsed_files)
  pretty_printing = create_pretty_printing(parsed_files)
  response = nanopb_write(results, pretty_printing)

  # Write to stdout
  io.open(sys.stdout.fileno(), 'wb').write(response.SerializeToString())


def use_malloc(request):
  """Mark all variable length items as requiring malloc.

  By default nanopb renders string, bytes, and repeated fields (dynamic fields)
  as having the C type pb_callback_t. Unfortunately this type is incompatible
  with nanopb's union support.

  The function performs the equivalent of adding the following annotation to
  each dynamic field in all the protos.

    string name = 1 [(nanopb).type = FT_POINTER];

  Args:
    request: A CodeGeneratorRequest from protoc. The descriptors are modified
      in place.
  """
  dynamic_types = [
    FieldDescriptorProto.TYPE_STRING,
    FieldDescriptorProto.TYPE_BYTES,
  ]

  for _, message_type in iterate_messages(request):
    for field in message_type.field:
      dynamic_type = field.type in dynamic_types
      repeated = field.label == FieldDescriptorProto.LABEL_REPEATED

      if dynamic_type or repeated:
        ext = field.options.Extensions[nanopb_pb2.nanopb]
        ext.type = nanopb_pb2.FT_POINTER


def use_anonymous_oneof(request):
  """Use anonymous unions for oneofs if they're the only one in a message.

  Equivalent to setting this option on messages where it applies:

    option (nanopb).anonymous_oneof = true;

  Args:
    request: A CodeGeneratorRequest from protoc. The descriptors are modified
      in place.
  """
  for _, message_type in iterate_messages(request):
    if len(message_type.oneof_decl) == 1:
      ext = message_type.options.Extensions[nanopb_pb2.nanopb_msgopt]
      ext.anonymous_oneof = True


def use_bytes_for_strings(request):
  """Always use the bytes type instead of string.

  By default, nanopb renders proto strings as having the C type char* and does
  not include a separate size field, getting the length of the string via
  strlen(). Unfortunately this prevents using strings with embedded nulls,
  which is something the wire format supports.

  Fortunately, string and bytes proto fields are identical on the wire and
  nanopb's bytes representation does have an explicit length, so this function
  changes the types of all string fields to bytes. The generated code will now
  contain pb_bytes_array_t.

  There's no nanopb or proto option to control this behavior. The equivalent
  would be to hand edit all the .proto files :-(.

  Args:
    request: A CodeGeneratorRequest from protoc. The descriptors are modified
      in place.
  """
  for names, message_type in iterate_messages(request):
    for field in message_type.field:
      if field.type == FieldDescriptorProto.TYPE_STRING:
        field.type = FieldDescriptorProto.TYPE_BYTES


def iterate_messages(request):
  """Iterates over all messages in all files in the request.

  Args:
    request: A CodeGeneratorRequest passed by protoc.

  Yields:
    names: a nanopb.Names object giving a qualified name for the message
    message_type: a DescriptorProto for the message.
  """
  for fdesc in request.proto_file:
    for names, message_type in nanopb.iterate_messages(fdesc):
      yield names, message_type


def nanopb_parse_options(request):
  """Parses nanopb_generator command-line options from the given request.

  Args:
    request: A CodeGeneratorRequest passed by protoc.

  Returns:
    Nanopb's options object, obtained via optparser.
  """
  # Parse options the same as nanopb_generator.main_plugin() does.
  args = shlex.split(request.parameter)
  options, _ = nanopb.optparser.parse_args(args)

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
  """Parses the files in the given request into nanopb ProtoFile objects.

  Args:
    request: A CodeGeneratorRequest, as passed by protoc.
    options: The command-line options from nanopb_parse_options.

  Returns:
    A dictionary of filename to nanopb.ProtoFile objects, each one representing
    the parsed form of a FileDescriptor in the request.
  """
  # Process any include files first, in order to have them available as
  # dependencies
  parsed_files = {}
  for fdesc in request.proto_file:
    parsed_files[fdesc.name] = nanopb.parse_file(fdesc.name, fdesc, options)

  return parsed_files


def create_pretty_printing(parsed_files):
  """Creates a `FilePrettyPrinting` for each of the given files.

  Args:
    parsed_files: A dictionary of proto file names (e.g. `foo/bar/baz.proto`) to
      `nanopb.ProtoFile` descriptors.

  Returns:
    A dictionary of short (without extension) proto file names (e.g.,
      `foo/bar/baz`) to `FilePrettyPrinting` objects.
  """
  pretty_printing = {}
  for name, parsed_file in parsed_files.items():
    base_filename = name.replace('.proto', '')
    pretty_printing[base_filename] = printing.FilePrettyPrinting(parsed_file)
  return pretty_printing


def nanopb_generate(request, options, parsed_files):
  """Generates C sources from the given parsed files.

  Args:
    request: A CodeGeneratorRequest, as passed by protoc.
    options: The command-line options from nanopb_parse_options.
    parsed_files: A dictionary of filename to nanopb.ProtoFile, as returned by
      nanopb_parse_files().

  Returns:
    A list of nanopb output dictionaries, each one representing the code
    generation result for each file to generate. The output dictionaries have
    the following form:

        {
          'headername': Name of header file, ending in .h,
          'headerdata': Contents of the header file,
          'sourcename': Name of the source code file, ending in .c,
          'sourcedata': Contents of the source code file
        }
  """
  output = []

  for filename in request.file_to_generate:
    for fdesc in request.proto_file:
      if fdesc.name == filename:
        results = nanopb.process_file(filename, fdesc, options, parsed_files)
        output.append(results)

  return output


def nanopb_write(results, pretty_printing):
  """Translates nanopb output dictionaries to a CodeGeneratorResponse.

  Args:
    results: A list of generated source dictionaries, as returned by
      nanopb_generate().
    file_pretty_printing: A dictionary of `FilePrettyPrinting` objects, indexed
      by short file name (without extension).

  Returns:
    A CodeGeneratorResponse describing the result of the code generation
    process to protoc.
  """
  response = plugin_pb2.CodeGeneratorResponse()

  for result in results:
    base_filename = result['headername'].replace('.nanopb.h', '')
    file_pretty_printing = pretty_printing[base_filename]

    generated_header = GeneratedFile(response.file, result['headername'],
                                           nanopb_fixup(result['headerdata']))
    nanopb_augment_header(generated_header, file_pretty_printing)

    generated_source = GeneratedFile(response.file, result['sourcename'],
                                           nanopb_fixup(result['sourcedata']))
    nanopb_augment_source(generated_source, file_pretty_printing)

  return response


class GeneratedFile:
  """Represents a request to generate a file.

  The initial contents of the file can be augmented by inserting extra text at
  insertion points. For each file, Nanopb defines the following insertion
  points (each marked `@@protoc_insertion_point`):

  - 'includes' -- beginning of the file, after the last Nanopb include;
  - 'eof' -- the very end of file, right before the include guard.

  In addition, each header also defines a 'struct:Foo' insertion point inside
  each struct declaration, where 'Foo' is the name of the struct.

  See the official protobuf docs for more information on insertion points:
  https://github.com/protocolbuffers/protobuf/blob/129a7c875fc89309a2ab2fbbc940268bbf42b024/src/google/protobuf/compiler/plugin.proto#L125-L162
  """

  def __init__(self, files, file_name, contents):
    """
    Args:
      files: The array of files to generate inside a `CodeGenerationResponse`.
        New files will be added to it.
      file_name: The name of the file to generate/augment.
      contents: The initial contents of the file, before any augmentation, as
        a single string.
    """
    self.files = files
    self.file_name = file_name

    self._set_contents(contents)

  def _set_contents(self, contents):
    """Creates a request to generate a new file with the given `contents`.
    """
    f = self.files.add()
    f.name = self.file_name
    f.content = contents

  def insert(self, insertion_point, to_insert):
    """Adds extra text to the generated file at the given `insertion_point`.

    Args:
      insertion_point: The string identifier of the insertion point, e.g. 'eof'.
        The extra text will be inserted right before the insertion point. If
        `insert` is called repeatedly, insertions will be added in the order of
        the calls. All possible insertion points are defined by Nanopb; see the
        class comment for additional details.
      to_insert: The text to insert as a string.
    """
    f = self.files.add()
    f.name = self.file_name
    f.insertion_point = insertion_point
    f.content = to_insert


def nanopb_fixup(file_contents):
  """Applies fixups to generated Nanopb code.

  This is for changes to the code, as well as additions that cannot be made via
  insertion points. Current fixups:
  - rename fields named `delete` to `delete_`, because it's a keyword in C++.

  Args:
    file_contents: The contents of the generated file as a single string. The
      fixups will be applied without distinguishing between the code and the
      comments.
  """

  delete_keyword = re.compile(r'\bdelete\b')
  return delete_keyword.sub('delete_', file_contents)


def nanopb_augment_header(generated_header, file_pretty_printing):
  """Augments a `.h` generated file with pretty-printing support.

  Also puts all code in `firebase::firestore` namespace.

  Args:
    generated_header: The `.h` file that will be generated.
    file_pretty_printing: `FilePrettyPrinting` for this header.
  """
  generated_header.insert('includes', '#include <string>\n\n')

  open_namespace(generated_header)

  for e in file_pretty_printing.enums:
    generated_header.insert('eof', e.generate_declaration())
  for m in file_pretty_printing.messages:
    generated_header.insert('struct:' + m.full_classname, m.generate_declaration())

  close_namespace(generated_header)


def nanopb_augment_source(generated_source, file_pretty_printing):
  """Augments a `.cc` generated file with pretty-printing support.

  Also puts all code in `firebase::firestore` namespace.

  Args:
    generated_source: The `.cc` file that will be generated.
    file_pretty_printing: `FilePrettyPrinting` for this source.
  """
  generated_source.insert('includes', textwrap.dedent('\
    #include "Firestore/core/src/nanopb/pretty_printing.h"\n\n'))

  open_namespace(generated_source)
  add_using_declarations(generated_source)

  for e in file_pretty_printing.enums:
    generated_source.insert('eof', e.generate_definition())
  for m in file_pretty_printing.messages:
    generated_source.insert('eof', m.generate_definition())

  close_namespace(generated_source)


def open_namespace(generated_file):
  """Augments a generated file by opening the `f::f` namespace.
  """
  generated_file.insert('includes', textwrap.dedent('''\
      namespace firebase {
      namespace firestore {\n\n'''))


def close_namespace(generated_file):
  """Augments a generated file by closing the `f::f` namespace.
  """
  generated_file.insert('eof', textwrap.dedent('''\
      }  // namespace firestore
      }  // namespace firebase\n\n'''))


def add_using_declarations(generated_file):
  """Augments a generated file by adding the necessary using declarations.
  """
  generated_file.insert('includes', '''\
using nanopb::PrintEnumField;
using nanopb::PrintHeader;
using nanopb::PrintMessageField;
using nanopb::PrintPrimitiveField;
using nanopb::PrintTail;\n\n''');


if __name__ == '__main__':
  main()

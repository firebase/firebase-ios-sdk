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

from google.protobuf.descriptor_pb2 import FieldDescriptorProto

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
  pretty_printing_info = create_pretty_printers(parsed_files)
  response = nanopb_write(results, pretty_printing_info)

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
    - a dictionary of filename to nanopb.ProtoFile objects, each one representing
    the parsed form of a FileDescriptor in the request;
    - a dictionary of filename (without `.proto` extension) to a
      `FilePrettyPrintingInfo` object, which contains information on how to
      generate pretty-printing code for this file.
  """
  # Process any include files first, in order to have them available as
  # dependencies
  parsed_files = {}
  for fdesc in request.proto_file:
    parsed_files[fdesc.name] = nanopb.parse_file(fdesc.name, fdesc, options)

  return parsed_files


def create_pretty_printers(parsed_files):
  pretty_printing_info = {}
  for name, parsed_file in parsed_files.items():
    base_filename = name.replace('.proto', '')
    pretty_printing_info[base_filename] = FilePrettyPrintingInfo(parsed_file,

                                                                  base_filename)
  return pretty_printing_info


class FileGenerationRequest:
  def __init__(self, files, file_name):
    self.files = files
    self.file_name = file_name


  def set_contents(self, contents):
    """Creates a file generation request with the given `file_contents`.
    """
    f = self.files.add()
    f.name = self.file_name
    f.content = self._fixup(contents)


  def insert(self, insertion_point, to_insert):
    """Creates and returns a pseudo-file request representing an insertion point.

    The file with the given `file_name` must already exist among `files` before
    this function is called.
    """
    f = self.files.add()
    f.name = self.file_name
    f.insertion_point = insertion_point
    f.content = to_insert


  def _fixup(self, file_contents):
    """Applies fixups to generated Nanopb code.

    This is for changes to the code, as well as additions that cannot be made via
    insertion points. Current fixups:
    - rename fields named `delete` to `delete_`, because it's a keyword in C++.
    """

    delete_keyword = re.compile(r'\bdelete\b')
    return delete_keyword.sub('delete_', file_contents)


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


def nanopb_write(results, pretty_printing_info):
  """Translates nanopb output dictionaries to a CodeGeneratorResponse.

  Args:
    results: A list of generated source dictionaries, as returned by
      nanopb_generate().
    pretty_printing_info: A dictionary of `FilePrettyPrintingInfo` objects,
      indexed by short file name (without extension).

  Returns:
    A CodeGeneratorResponse describing the result of the code generation
    process to protoc.
  """
  response = plugin_pb2.CodeGeneratorResponse()

  for result in results:
    base_filename = result['headername'].replace('.nanopb.h', '')
    file_printer = pretty_printing_info[base_filename]

    header_request = FileGenerationRequest(response.file, result['headername'])
    generate_header(header_request, result['headerdata'], file_printer)
    source_request = FileGenerationRequest(response.file, result['sourcename'])
    generate_source(source_request, result['sourcedata'], file_printer)

  return response


def open_namespace(request):
  """Opens the `firebase::firestore` namespace in file with given `file_name`.
  """
  request.insert('includes', '''\
namespace firebase {
namespace firestore {\n\n''')


def close_namespace(request):
  """Closes the `firebase::firestore` namespace in file with given `file_name`.
  """
  request.insert('eof', '''\
}  // namespace firestore
}  // namespace firebase\n\n''')


def indent(level):
  """Returns leading whitespace corresponding to the given indentation `level`.
  """
  indent_per_level = 4
  return ' ' * (indent_per_level * level)


def generate_header(request, file_contents, file_printer):
  """Generates `.h` file with given contents, and with pretty-printing support.
  """
  request.set_contents(file_contents)

  request.insert('includes', '#include <string>\n\n')

  open_namespace(request)

  declare_tostring(request, file_printer.messages)
  declare_enum_tostring(request, file_printer.enums)

  close_namespace(request)


def declare_tostring(request, messages):
  """Creates a declaration of `ToString` member function for each Nanopb class.
  """
  for m in messages:
    insertion_point = 'struct:' + m.full_classname
    declaration = '\n' + indent( 1) + 'std::string ToString(int indent = 0) const;\n'
    request.insert(insertion_point, declaration)


def declare_enum_tostring(request, enums):
  """Creates a declaration of `EnumToString` free function for each enum.
  """
  for enum in enums:
    request.insert('eof', enum.generate_declaration())


def generate_source(request, file_contents, file_printer):
  """Generates `.cc` file with given contents, and with pretty-printing support.
  """
  request.set_contents(file_contents)

  request.insert('includes', '#include "nanopb_pretty_printers.h"\n\n')

  open_namespace(request)

  define_enum_tostring(request, file_printer.enums)
  define_tostring(request, file_printer.messages)

  close_namespace(request)


def define_tostring(request, messages):
  """Creates the definition of `ToString` member function for each Nanopb class.
  """
  for m in messages:
    result = '''\
std::string %s::ToString(int indent) const {
    std::string header = PrintHeader(indent, "%s", this);
    std::string result;\n\n''' % (m.full_classname, m.short_classname)

    for field in m.fields:
      result += str(field)

    can_be_empty = all(f.is_primitive or f.is_repeated for f in m.fields)
    if can_be_empty:
      result += '''
    bool is_root = indent == 0;
    if (!result.empty() || is_root) {
      std::string tail = PrintTail(indent);
      return header + result + tail;
    } else {
      return "";
    }
}\n\n'''
    else:
      result += '''
    std::string tail = PrintTail(indent);
    return header + result + tail;
}\n\n'''

    request.insert('eof', result)


def define_enum_tostring(request, enums):
  """Creates the definition of `EnumToString` free function for each enum.
  """
  for enum in enums:
    request.insert('eof', enum.generate_definition())


if __name__ == '__main__':
  main()

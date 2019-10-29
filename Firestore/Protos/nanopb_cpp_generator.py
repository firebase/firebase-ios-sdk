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
  pretty_printing_info = {};
  parsed_files = nanopb_parse_files(request, options, pretty_printing_info)
  results = nanopb_generate(request, options, parsed_files)
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


def nanopb_parse_files(request, options, pretty_printing_info):
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
    parsed_file = nanopb.parse_file(fdesc.name, fdesc, options)
    parsed_files[fdesc.name] = parsed_file

    base_filename = fdesc.name.replace('.proto', '')
    pretty_printing_info[base_filename] = FilePrettyPrintingInfo(parsed_file)

  return parsed_files


class FilePrettyPrintingInfo:
  def __init__(self, parsed_file):
    self.messages = [MessagePrettyPrintingInfo(m) for m in parsed_file.messages]
    self.enums = [EnumPrettyPrintingInfo(e) for e in parsed_file.enums]


class MessagePrettyPrintingInfo:
  def __init__(self, message):
    self.short_classname = message.name.parts[-1]
    self.full_classname = str(message.name)
    self.fields = [self._create_field(f, message) for f in message.fields]
    # Make sure fields are printed ordered by tag, for consistency with official
    # proto libraries.
    self.fields.sort(key = lambda f: f.tag)


  def _create_field(self, field, message):
    if isinstance(field, nanopb.OneOf):
      return OneOfMemberPrettyPrintingInfo(field, message)
    else:
      return FieldPrettyPrintingInfo(field, message)


class FieldPrettyPrintingInfo:
  def __init__(self, field, message):
    self.name = field.name
    self.full_classname = str(message.name)

    self.tag = field.tag

    self.is_optional = field.rules == 'OPTIONAL' and field.allocation == 'STATIC'
    self.is_repeated = field.rules == 'REPEATED'
    self.is_oneof = False

    self.is_primitive = field.pbtype != 'MESSAGE'
    self.is_enum = field.pbtype in ['ENUM', 'UENUM']


class OneOfMemberPrettyPrintingInfo(FieldPrettyPrintingInfo):
  def __init__(self, field, message):
    FieldPrettyPrintingInfo.__init__(self, field, message)

    self.is_oneof = True

    self.which = 'which_' + field.name
    self.is_anonymous = field.anonymous
    self.fields = [FieldPrettyPrintingInfo(f, message) for f in field.fields]


class EnumPrettyPrintingInfo:
  def __init__(self, enum):
    self.name = str(enum.names)
    self.members = [str(n) for n in enum.value_longnames]


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

  Returns:
    A CodeGeneratorResponse describing the result of the code generation
    process to protoc.
  """
  response = plugin_pb2.CodeGeneratorResponse()

  for result in results:
    base_filename = result['headername'].replace('.nanopb.h', '')
    file_printers = pretty_printing_info[base_filename]

    generate_header(response.file, result['headername'], result['headerdata'], file_printers)
    generate_source(response.file, result['sourcename'], result['sourcedata'], file_printers)

  return response


def begin_namespace(files, file_name):
  f = create_insertion(files, file_name, 'includes')
  f.content = '''\
namespace firebase {
namespace firestore {'''


def end_namespace(files, file_name):
  f = create_insertion(files, file_name, 'eof')
  f.content = '''\
}  // namespace firestore
}  // namespace firebase'''


def indent(level):
  """Returns leading whitespace corresponding to the given indentation level."""
  indent_per_level = 4
  return ' ' * (indent_per_level * level)


def fixup(file_contents):
  """Applies fixups to generated Nanopb code.

  This is for changes to the code, as well as additions that cannot be made via
  insertion points. Current fixups:
  - rename fields named `delete` to `delete_`, because it's a keyword in C++.
  """

  delete_keyword = re.compile(r'\bdelete\b')
  return delete_keyword.sub('delete_', file_contents)


def create_insertion(files, file_name, insertion_point):
  f = files.add()
  f.name = file_name
  f.insertion_point = insertion_point
  return f


def add_contents(files, file_name, file_contents):
  f = files.add()
  f.name = file_name
  f.content = fixup(file_contents)


def generate_header(files, file_name, file_contents, file_printers):
  add_contents(files, file_name, file_contents)

  # Includes
  f = create_insertion(files, file_name, 'includes')
  f.content = '#include <string>\n\n'

  begin_namespace(files, file_name)

  add_field_printer_declarations(files, file_name, file_printers.messages)
  add_enum_printer_declarations(files, file_name, file_printers.enums)

  end_namespace(files, file_name)


def add_field_printer_declarations(files, file_name, messages):
  for m in messages:
    f = create_insertion(files, file_name, 'struct:' + m.full_classname)
    f.content = '\n' + indent(1) + 'std::string ToString(int indent = 0) const;\n'


def add_enum_printer_declarations(files, file_name, enums):
  for enum in enums:
    f = create_insertion(files, file_name, 'eof')
    f.content += 'const char* EnumToString(%s\nvalue);\n;' % (enum.name)


def generate_source(files, file_name, file_contents, file_printers):
  add_contents(files, file_name, file_contents)

  # Includes
  f = create_insertion(files, file_name, 'includes')
  f.content = '''\
#include "absl/strings/str_cat.h"
#include "nanopb_pretty_printers.h"\n\n'''

  begin_namespace(files, file_name)

  add_enum_printer_definitions(files, file_name, file_printers.enums)
  add_field_printer_definitions(files, file_name, file_printers.messages)

  end_namespace(files, file_name)


def add_field_printer_definitions(files, file_name, messages):
  for m in messages:
    f = create_insertion(files, file_name, 'eof')

    f.content += '''\
std::string %s::ToString(int indent) const {
    bool is_root = indent == 0;
    if (is_root) {
        indent = 1;
    }

    std::string header = PrintHeader(is_root, "%s", this);
    std::string result;\n\n''' % (m.full_classname, m.short_classname)

    for field in m.fields:
      f.content += add_printing_for_field(field)

    can_be_empty = all(f.is_primitive or f.is_repeated for f in m.fields)
    if can_be_empty:
      f.content += '''
    if (!result.empty() || is_root) {
      std::string tail = PrintTail(is_root, indent);
      return header + result + tail;
    } else {
      return "";
    }
}\n\n'''
    else:
      f.content += '''
    std::string tail = PrintTail(is_root, indent);
    return header + result + tail;
}\n\n'''


def add_enum_printer_definitions(files, file_name, enums):
  for enum in enums:
    f = create_insertion(files, file_name, 'eof')

    f.content += '''\
const char* EnumToString(
  %s value) {
    switch (value) {\n''' % (enum.name)

    for full_name in enum.members:
      short_name = full_name.replace('%s_' % enum.name, '')
      f.content += '''\
    case %s:
        return "%s";\n''' % (full_name, short_name)

    f.content += '''
    }
    return "<unknown enum value>";
}\n\n'''


def add_printing_for_field(field):
  if field.is_optional:
    return add_printing_for_optional(field)
  elif field.is_repeated:
    return add_printing_for_repeated(field)
  elif field.is_oneof:
    return add_printing_for_oneof(field)
  else:
    return add_printing_for_leaf(field)


def add_printing_for_oneof(oneof):
  which = oneof.which
  result = '''\
    switch (%s) {\n''' % (which)

  for f in oneof.fields:
    tag_name = '%s_%s_tag' % (oneof.full_classname, f.name)
    result += '''\
    case %s:\n''' % tag_name

    result += add_printing_for_leaf(f, indent=2, parent_oneof=oneof, always_print=True)
    result += '''\
        break;\n'''

  result += '''\
    }\n'''

  return result


def add_printing_for_repeated(field):
  count = field.name + '_count'

  result = '''\
    for (pb_size_t i = 0; i != %s; ++i) {\n''' % count
  result += add_printing_for_leaf(field, indent=2, always_print=True)
  result += '''\
    }\n'''

  return result


def add_printing_for_optional(field):
  name = field.name
  result = '''\
    if (has_%s) {\n''' % name
  result += add_printing_for_leaf(field, indent=2, always_print=True)
  result += '''\
    }\n'''

  return result


def add_printing_for_leaf(field, **kwargs):
  indent_level = kwargs.get('indent') or 1
  always_print = 'true' if kwargs.get('always_print') else 'false'
  parent_oneof = kwargs.get('parent_oneof')

  display_name = field.name
  cc_name = display_name

  if field.is_repeated:
    cc_name += '[i]'

  if parent_oneof and not parent_oneof.is_anonymous:
    cc_name = parent_oneof.name + '.' + cc_name

  if cc_name == 'delete':
    cc_name = 'delete_'
  if field.is_primitive:
    display_name += ':'

  function_name = ''
  if field.is_enum:
    function_name = 'PrintEnumField'
  elif field.is_primitive:
    function_name = 'PrintPrimitiveField'
  else:
    function_name = 'PrintMessageField'

  line_width = 80

  format_str = '%sresult += %s("%s ",%s%s, indent + 1, %s);\n'
  maybe_linebreak = ' '
  args = (indent(indent_level), function_name, display_name, maybe_linebreak, cc_name, always_print)

  result = format_str % args
  if len(result) <= line_width:
    return result

  maybe_linebreak = '\n' + indent(indent_level + 1)
  args = (indent(indent_level), function_name, display_name, maybe_linebreak, cc_name, always_print)
  return format_str % args


if __name__ == '__main__':
  main()

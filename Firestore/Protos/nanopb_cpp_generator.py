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


class OneOfMemberPrettyPrintingInfo:
  def __init__(self, field, message):
    self.which = 'which_' + field.name
    self.is_anonymous = field.anonymous
    self.fields = [FieldPrettyPrintingInfo(f, message) for f in field.fields]


class FieldPrettyPrintingInfo:
  def __init__(self, field, message):
    self.name = field.name
    self.full_classname = str(message.name)

    self.tag = field.tag

    self.is_optional = field.rules == 'OPTIONAL' and field.allocation == 'STATIC'
    self.is_repeated = field.rules == 'REPEATED'
    self.is_primitive = field.pbtype != 'MESSAGE'

    self.is_enum = field.pbtype in ['ENUM', 'UENUM']

    if isinstance(field, nanopb.OneOf):
      self.oneof_member = OneOfMemberPrettyPrintingInfo(field, message)
    else:
      self.oneof_member = None


class EnumPrettyPrintingInfo:
  def __init__(self, enum):
    self.name = str(enum.names)
    self.members = [str(n) for n in enum.value_longnames]


class MessagePrettyPrintingInfo:
  def __init__(self, message):
    self.short_classname = message.name.parts[-1]
    self.full_classname = str(message.name)
    self.fields = [FieldPrettyPrintingInfo(f, message) for f in message.fields]
    self.fields.sort(key = lambda f: f.tag)


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
    generate_header(response.file, result['headername'], result['headerdata'], pretty_printing_info)
    generate_source(response.file, result['sourcename'], result['sourcedata'], pretty_printing_info)

  return response


def add_contents(files, file_name, file_contents):
  f = files.add()
  f.name = file_name

  delete_keyword = re.compile(r'\bdelete\b')
  f.content = delete_keyword.sub('delete_', file_contents)


def generate_header(files, file_name, file_contents, pretty_printing_info):
  add_contents(files, file_name, file_contents)

  # Includes
  f = files.add()
  f.name = file_name
  f.insertion_point = 'includes'
  f.content = '#include <string>\n\n'

  begin_namespace(files, file_name)

  # `ToString` declarations
  base_filename = file_name.replace('.nanopb.h', '')
  for p in pretty_printing_info[base_filename].messages:
    f = files.add()
    f.name = file_name
    f.insertion_point = 'struct:' + p.full_classname
    f.content = '\n' + ' ' * 4 + 'std::string ToString(int indent = 0) const;\n'

  # `EnumToString` declarations
  for enum in pretty_printing_info[base_filename].enums:
    f = files.add()
    f.name = file_name
    f.insertion_point = 'eof'
    f.content += '''const char* EnumToString(
  %s value);\n''' % (enum.name)

  end_namespace(files, file_name)


def generate_source(files, file_name, file_contents, pretty_printing_info):
  add_contents(files, file_name, file_contents)

  # Includes
  f = files.add()
  f.name = file_name
  f.insertion_point = 'includes'
  f.content = '''#include "absl/strings/str_cat.h"
#include "nanopb_pretty_printers.h"\n\n'''

  begin_namespace(files, file_name)

  base_filename = file_name.replace('.nanopb.cc', '')

  # Enums
  for enum in pretty_printing_info[base_filename].enums:
    f = files.add()
    f.name = file_name
    f.insertion_point = 'eof'

    f.content += '''const char* EnumToString(
  %s value) {
    switch (value) {''' % (enum.name)

    for full_name in enum.members:
      short_name = full_name.replace('%s_' % enum.name, '')
      f.content += '''
    case %s:
        return "%s";''' % (full_name, short_name)

    f.content += '''
    }
    return "<unknown enum value>";
}\n\n'''

  # Printers
  for p in pretty_printing_info[base_filename].messages:
    f = files.add()
    f.name = file_name
    f.insertion_point = 'eof'

    # ToString
    f.content += '''std::string %s::ToString(int indent) const {
    std::string result;

    bool is_root = indent == 0;
    std::string header;
    if (is_root) {
        indent = 1;
        auto p = absl::Hex{reinterpret_cast<uintptr_t>(this)};
        absl::StrAppend(&header, "<%s 0x", p, ">: {\\n");
    } else {
        header = "{\\n";
    }\n\n''' % (p.full_classname, p.short_classname)

    for field in p.fields:
      f.content += ' ' * 4 + add_printing_for_field(field) + '\n'

    can_be_empty = all(f.is_primitive or f.is_repeated for f in p.fields)
    if can_be_empty:
      f.content += '''
    if (!result.empty() || is_root) {
      std::string tail = Indent(is_root ? 0 : indent) + '}';
      return header + result + tail;
    } else {
      return "";
    }
}\n\n'''
    else:
      f.content += '''
    std::string tail = Indent(is_root ? 0 : indent) + '}';
    return header + result + tail;
}\n\n'''

  end_namespace(files, file_name)


def add_printing_for_field(field):
  if field.is_optional:
    return add_printing_for_optional(field)
  elif field.is_repeated:
    return add_printing_for_repeated(field)
  elif field.oneof_member:
    return add_printing_for_oneof(field)
  else:
    return add_printing_for_leaf(field)


def add_printing_for_oneof(oneof):
  which = oneof.oneof_member.which
  result = 'switch (%s) {\n' % (which)

  for f in oneof.oneof_member.fields:
    tag_name = '%s_%s_tag' % (oneof.full_classname, f.name)
    result += ' ' * 4 + 'case %s:' % tag_name

    result += '\n' + ' ' * 8 + add_printing_for_leaf(f, oneof, True)
    result += '\n' + ' ' * 8 + 'break;\n'

  return result + ' ' * 4 + '}\n'


def add_printing_for_repeated(field):
  count = field.name + '_count'

  result = 'for (pb_size_t i = 0; i != %s; ++i) {\n' % count
  result += ' ' * 8 + add_printing_for_leaf(field, None, True) + '\n'
  result += ' ' * 4 + '}'

  return result


def add_printing_for_optional(field):
  name = field.name
  result = 'if (has_%s) {\n' % name
  result += ' ' * 8 + add_printing_for_leaf(field, None, True) + '\n'
  result += ' ' * 4 + '}'

  return result


def add_printing_for_leaf(field, parent=None, always_print=False):
  display_name = field.name
  cc_name = display_name
  if display_name == 'delete':
    cc_name += '_'
  if parent and not parent.oneof_member.is_anonymous:
    cc_name = parent.name + '.' + cc_name
  if field.is_repeated:
    cc_name += '[i]'

  if display_name == 'delete_':
    display_name = 'delete'
  if field.is_primitive:
    display_name += ': '
  else:
    display_name += ' '

  function_name = ''
  if field.is_enum:
    function_name = 'PrintEnumField'
  elif field.is_primitive:
    function_name = 'PrintPrimitiveField'
  else:
    function_name = 'PrintMessageField'

  return '''result += %s("%s", %s, indent + 1, %s);''' % (function_name, display_name, cc_name, 'true' if always_print else 'false')


def begin_namespace(files, filename):
    f = files.add()
    f.name = filename
    f.insertion_point = 'includes'
    f.content = '''\
namespace firebase {
namespace firestore {'''


def end_namespace(files, file_name):
    f = files.add()
    f.name = file_name
    f.insertion_point = 'eof'
    f.content = '''\
}  // namespace firestore
}  // namespace firebase'''


  # """Renames a delete symbol to delete_.

  # If a proto uses a field named 'delete', nanopb happily uses that in the
  # message definition. Works fine for C; not so much for C++.

  # Args:
  #   lines: The lines to fix.

  # Returns:
  #   The lines, fixed.
  # """

# TODO:
# 1. Array and oneof should properly print enums.
#
# 1. Code cleanup, line breaks in generated code.
#
# Repeated oneof is not supported.
# Oneofs cannot have repeated members
# (presumably cannot have repeated inside repeated?)
# (can you nest oneofs?)

if __name__ == '__main__':
  main()

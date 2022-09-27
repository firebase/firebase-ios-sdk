#!/usr/bin/env python

# Copyright 2019 Google
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

import textwrap

from google.protobuf.descriptor_pb2 import FieldDescriptorProto
import nanopb_generator as nanopb


LINE_WIDTH = 80


def _indent(level):
  """Returns leading whitespace corresponding to the given indentation `level`.
  """

  indent_per_level = 4
  return ' ' * (indent_per_level * level)


class FilePrettyPrinting:
  """Allows generating pretty-printing support for a proto file.

  Because two files (header and source) are generated for each proto file, this
  class doesn't generate the necessary code directly. Use `messages` and `enums`
  properties to generate the declarations and definitions separately and insert
  them to the appropriate locations within the generated files.
  """

  def __init__(self, file_desc):
    """Args:
      file_desc: nanopb.ProtoFile describing this proto file.
    """

    self.messages = [MessagePrettyPrinting(m) for m in
                     file_desc.messages]
    self.enums = [EnumPrettyPrinting(e) for e in file_desc.enums]


class MessagePrettyPrinting:
  """Generates pretty-printing support for a message.

  Adds the following member function to the Nanopb generated class:

  std::string ToString(int indent = 0) const;

  Because the generated code is split between a header and a source, the
  declaration and definition are generated separately. Definition has the
  out-of-class form.

  The output of the generated function represents the proto in its text form,
  suitable for parsing, and with proper indentation. The top-level message
  additionally displays message name and the value of the pointer to `this`.
  """

  def __init__(self, message_desc):
    """Args:
      message_desc: nanopb.Message describing this message.
    """

    self.full_classname = str(message_desc.name)
    self._short_classname = message_desc.name.parts[-1]

    self._fields = [self._create_field(f, message_desc) for f in
                    message_desc.fields]
    # Make sure fields are printed ordered by tag, for consistency with official
    # proto libraries.
    self._fields.sort(key=lambda f: f.tag)

  def _create_field(self, field_desc, message_desc):
    if isinstance(field_desc, nanopb.OneOf):
      return OneOfPrettyPrinting(field_desc, message_desc)
    else:
      return FieldPrettyPrinting(field_desc, message_desc)

  def generate_declaration(self):
    """Generates the declaration of a `ToString()` member function.
    """

    return '\n' + _indent(1) + 'std::string ToString(int indent = 0) const;\n'

  def generate_definition(self):
    """Generates the out-of-class definition of a `ToString()` member function.
    """

    result = '''\
std::string %s::ToString(int indent) const {
    std::string tostring_header = PrintHeader(indent, "%s", this);
    std::string tostring_result;\n\n''' % (
    self.full_classname, self._short_classname)

    for field in self._fields:
      result += str(field)

    can_be_empty = all(f.is_primitive or f.is_repeated for f in self._fields)
    if can_be_empty:
      result += '''
    bool is_root = indent == 0;
    if (!tostring_result.empty() || is_root) {
      std::string tostring_tail = PrintTail(indent);
      return tostring_header + tostring_result + tostring_tail;
    } else {
      return "";
    }
}\n\n'''
    else:
      result += '''
    std::string tostring_tail = PrintTail(indent);
    return tostring_header + tostring_result + tostring_tail;
}\n\n'''

    return result


class FieldPrettyPrinting:
  """Generates pretty-printing support for a field.

  The generated C++ code will output the field name and value; the output format
  is the proto text format, suitable for parsing. Unset fields are not printed.
  Repeated and optional fields are supported.

  Oneofs are not supported; use `OneOfPrettyPrinting` instead.

  The actual output will be delegated to a C++ function called
  `PrintPrimitiveField()`, `PrintEnumField()`, or `PrintMessageField()`,
  according to the field type; the function is expected to be visible at the
  point of definition.
  """

  def __init__(self, field_desc, message_desc):
    """Args:
      field_desc: nanopb.Field describing this field.
      message_desc: nanopb.Message describing the message containing this field.
    """

    self.name = field_desc.name
    self.tag = field_desc.tag

    self.is_optional = (field_desc.rules == 'OPTIONAL' and field_desc.allocation == 'STATIC')
    self.is_repeated = field_desc.rules == 'REPEATED'
    self.is_primitive = field_desc.pbtype != 'MESSAGE'
    self.is_enum = field_desc.pbtype in ['ENUM', 'UENUM']

  def __str__(self):
    """Generates a C++ statement that prints the field according to its type.
    """

    if self.is_optional:
      return self._generate_for_optional()
    elif self.is_repeated:
      return self._generate_for_repeated()
    else:
      return self._generate_for_leaf()

  def _generate_for_repeated(self):
    """Generates a C++ statement that prints the repeated field, if non-empty.
    """

    count = self.name + '_count'

    result = '''\
    for (pb_size_t i = 0; i != %s; ++i) {\n''' % count
    # If the repeated field is non-empty, print all its members, even if they are
    # zero or empty (otherwise, an array of zeroes would be indistinguishable from
    # an empty array).
    result += self._generate_for_leaf(indent=2, always_print=True)
    result += '''\
    }\n'''

    return result

  def _generate_for_optional(self):
    """Generates a C++ statement that prints the optional field, if set.
    """

    name = self.name
    result = '''\
    if (has_%s) {\n''' % name
    # If an optional field is set, always print the value, even if it's zero or
    # empty.
    result += self._generate_for_leaf(indent=2, always_print=True)
    result += '''\
    }\n'''

    return result

  def _generate_for_leaf(self, indent=1, always_print=False, parent_oneof=None):
    """Generates a C++ statement that prints the "leaf" field.

    "Leaf" is to indicate that this function is non-recursive. If the field is
    a message type, the generated code will delegate printing to its
    `ToString()` member function.

    Args:
      indent: The indentation level of the generated statement.
      always_print: If `False`, the field will not be printed if it has the
        default value, or for a message, if each field it contains has the
        default value.
      parent_oneof: If the field is a member of a oneof, a reference to the
        corresponding `OneOfPrettyPrinting`
    """

    always_print = 'true' if always_print else 'false'

    display_name = self.name
    if self.is_primitive:
      display_name += ':'

    cc_name = self._get_cc_name(parent_oneof)
    function_name = self._get_printer_function_name()

    return self._generate(indent, display_name, cc_name, function_name,
                          always_print)

  def _get_cc_name(self, parent_oneof):
    """Gets the name of the field to use in the generated C++ code:

    - for repeated fields, appends indexing in the form of `[i]`;
    - for named union members, prepends the name of the enclosing union;
    - ensures the name isn't a C++ keyword by appending an underscore
      (currently, only for keyword `delete`).
    """

    cc_name = self.name

    # If a proto field is named `delete`, it is renamed to `delete_` by our script
    # because `delete` is a keyword in C++. Unfortunately, the renaming mechanism
    # runs separately from generating pretty printers; consequently, when pretty
    # printers are being generated, all proto fields still have their unmodified
    # names.
    if cc_name == 'delete':
      cc_name = 'delete_'

    if self.is_repeated:
      cc_name += '[i]'

    if parent_oneof and not parent_oneof.is_anonymous:
      cc_name = parent_oneof.name + '.' + cc_name

    return cc_name

  def _get_printer_function_name(self):
    """Gets the name of the C++ function to delegate printing to.
    """

    if self.is_enum:
      return 'PrintEnumField'
    elif self.is_primitive:
      return 'PrintPrimitiveField'
    else:
      return 'PrintMessageField'

  def _generate(self, indent_level, display_name, cc_name, function_name,
                always_print):
    """Generates the C++ statement that prints the field.

    Args:
      indent_level: The indentation level of the generated statement.
      display_name: The name of the field to display in the output.
      cc_name: The name of the field to use in the generated C++ code; may
        differ from `display_name`.
      function_name: The C++ function to delegate printing the value to.
      always_print: Whether to print the field if it has its default value.
    """

    format_str = '%stostring_result += %s("%s ",%s%s, indent + 1, %s);\n'
    for maybe_linebreak in [' ', '\n' + _indent(indent_level + 1)]:
      args = (
        _indent(indent_level), function_name, display_name, maybe_linebreak,
        cc_name,
        always_print)

      result = format_str % args
      # Best-effort attempt to fit within the expected line width.
      if len(result) <= LINE_WIDTH:
        break

    return result


class OneOfPrettyPrinting(FieldPrettyPrinting):
  """Generates pretty-printing support for a oneof field.

  This class represents the "whole" oneof, with all of its members nested, not
  a single oneof member.
  Note that all members of the oneof are nested (in `_fields` property).
  """

  def __init__(self, field_desc, message_desc):
    """Args:
      field_desc: nanopb.Field describing this oneof field.
      message_desc: nanopb.Message describing the message containing this field.
    """

    FieldPrettyPrinting.__init__(self, field_desc, message_desc)

    self._full_classname = str(message_desc.name)

    self._which = 'which_' + field_desc.name
    self.is_anonymous = field_desc.anonymous
    self._fields = [FieldPrettyPrinting(f, message_desc) for f in
                    field_desc.fields]

  def __str__(self):
    """Generates a C++ statement that prints the oneof field, if it is set.
    """

    which = self._which
    result = '''\
    switch (%s) {\n''' % which

    for f in self._fields:
      tag_name = '%s_%s_tag' % (self._full_classname, f.name)
      result += '''\
    case %s:\n''' % tag_name

      # If oneof is set, always print that member, even if it's zero or empty.
      result += f._generate_for_leaf(indent=2, parent_oneof=self,
                                     always_print=True)
      result += '''\
        break;\n'''

    result += '''\
    }\n'''

    return result


class EnumPrettyPrinting:
  """Generates pretty-printing support for an enumeration.

  Adds the following free function to the file:

  const char* EnumToString(SomeEnumType value);

  Because the generated code is split between a header and a source, the
  declaration and definition are generated separately.

  The output of the generated function represents the string value of the given
  enum constant. If the given value is not part of the enum, a string
  representing an error is returned.
  """

  def __init__(self, enum_desc):
    """Args:
      enum_desc: nanopb.Enum describing this enumeration.
    """

    self.name = str(enum_desc.names)
    self._members = [str(n) for n in enum_desc.value_longnames]

  def generate_declaration(self):
    """Generates the declaration of a `EnumToString()` free function.
    """

    # Best-effort attempt to fit within the expected line width.
    format_str = 'const char* EnumToString(%s%s value);\n'
    for maybe_linebreak in ['', '\n' + _indent(1)]:
      args = (maybe_linebreak, self.name)
      result = format_str % args
      # Best-effort attempt to fit within the expected line width.
      if len(result) <= LINE_WIDTH:
        break

    return result

  def generate_definition(self):
    """Generates the definition of a `EnumToString()` free function.
    """

    result = '''\
const char* EnumToString(
  %s value) {
    switch (value) {\n''' % self.name

    for full_name in self._members:
      short_name = full_name.replace('%s_' % self.name, '')
      result += '''\
    case %s:
        return "%s";\n''' % (full_name, short_name)

    result += '''\
    }
    return "<unknown enum value>";
}\n\n'''

    return result

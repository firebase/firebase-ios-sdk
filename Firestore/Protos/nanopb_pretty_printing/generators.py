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

from google.protobuf.descriptor_pb2 import FieldDescriptorProto
import nanopb_generator as nanopb

def indent(level):
  """Returns leading whitespace corresponding to the given indentation `level`.
  """
  indent_per_level = 4
  return ' ' * (indent_per_level * level)


class FilePrettyPrintingGenerator:
  """Describes how to generate pretty-printing code for this file."""

  def __init__(self, parsed_file, base_filename):
    self.name = base_filename

    self.messages = [MessagePrettyPrintingGenerator(m) for m in parsed_file.messages]
    self.enums = [EnumPrettyPrintingGenerator(e) for e in parsed_file.enums]


class MessagePrettyPrintingGenerator:
  """Describes how to generate pretty-printing code for this message.
  """

  def __init__(self, message_desc):
    self.full_classname = str(message_desc.name)
    self._short_classname = message_desc.name.parts[-1]

    self._fields = [self._create_field(f, message_desc) for f in message_desc.fields]
    # Make sure fields are printed ordered by tag, for consistency with official
    # proto libraries.
    self._fields.sort(key=lambda f: f.tag)

  def _create_field(self, field_desc, message_desc):
    if isinstance(field_desc, nanopb.OneOf):
      return OneOfPrettyPrintingGenerator(field_desc, message_desc)
    else:
      return FieldPrettyPrintingGenerator(field_desc, message_desc)


  def generate_declaration(self):
    """Creates a declaration of `ToString` member function for each Nanopb class.
    """
    return '\n' + indent( 1) + 'std::string ToString(int indent = 0) const;\n'


  def generate_definition(self):
    """Creates the definition of `ToString` member function for each Nanopb class.
    """
    result = '''\
std::string %s::ToString(int indent) const {
    std::string header = PrintHeader(indent, "%s", this);
    std::string result;\n\n''' % (self.full_classname, self._short_classname)

    for field in self._fields:
      result += str(field)

    can_be_empty = all(f.is_primitive or f.is_repeated for f in self._fields)
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

    return result


class FieldPrettyPrintingGenerator:
  """Describes how to generate pretty-printing code for this field.
  """

  def __init__(self, field_desc, message_desc):
    self.name = field_desc.name
    self.tag = field_desc.tag

    self.is_optional = field_desc.rules == 'OPTIONAL' and field_desc.allocation == 'STATIC'
    self.is_repeated = field_desc.rules == 'REPEATED'
    self.is_primitive = field_desc.pbtype != 'MESSAGE'
    self.is_enum = field_desc.pbtype in ['ENUM', 'UENUM']


  def __str__(self):
    """Generates a C++ statement that can print `field` according to its type.
    """
    if self.is_optional:
      return self._generate_for_optional()
    elif self.is_repeated:
      return self._generate_for_repeated()
    else:
      return self._generate_for_leaf()


  def _generate_for_repeated(self):
    """Generates a C++ statement that can print the repeated `field`, if non-empty.
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
    """Generates a C++ statement that can print the optional `field`, if set.
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
    """Generates a C++ statement that can print the given "leaf" `field`.

    Leaf is to indicate that this function is non-recursive. If `field` is
    a message, the generated code will delegate printing to its `ToString()`
    member function.
    """
    always_print = 'true' if always_print else 'false'

    display_name = self.name
    if self.is_primitive:
      display_name += ':'

    cc_name = self._get_cc_name(parent_oneof)
    function_name = self._get_printer_function_name()

    return self._generate(indent, display_name, cc_name, function_name, always_print)


  def _get_cc_name(self, parent_oneof):
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

    if parent_oneof and not parent_oneof._is_anonymous:
      cc_name = parent_oneof.name + '.' + cc_name

    return cc_name


  def _get_printer_function_name(self):
    if self.is_enum:
      return 'PrintEnumField'
    elif self.is_primitive:
      return 'PrintPrimitiveField'
    else:
      return 'PrintMessageField'


  def _generate(self, indent_level, display_name, cc_name, function_name, always_print):
    line_width = 80

    format_str = '%sresult += %s("%s ",%s%s, indent + 1, %s);\n'
    maybe_linebreak = ' '
    args = (
      indent(indent_level), function_name, display_name, maybe_linebreak, cc_name,
      always_print)

    result = format_str % args
    if len(result) <= line_width:
      return result

    # Best-effort attempt to fit within the expected line width.
    maybe_linebreak = '\n' + indent(indent_level + 1)
    args = (
      indent(indent_level), function_name, display_name, maybe_linebreak, cc_name,
      always_print)
    return format_str % args


class OneOfPrettyPrintingGenerator(FieldPrettyPrintingGenerator):
  """Describes how to generate pretty-printing code for this oneof field.

  Note that all members of the oneof are nested (in `_fields` property).
  """

  def __init__(self, field_desc, message_desc):
    FieldPrettyPrintingGenerator.__init__(self, field_desc, message_desc)

    self._full_classname = str(message_desc.name)

    self._which = 'which_' + field_desc.name
    self._is_anonymous = field_desc.anonymous
    self._fields = [FieldPrettyPrintingGenerator(f, message_desc) for f in field_desc.fields]


  def __str__(self):
    """Generates a C++ statement that can print the `oneof` field, if it is set.
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


class EnumPrettyPrintingGenerator:
  """Describes how to generate pretty-printing code for this enum.
  """

  def __init__(self, enum):
    self.name = str(enum.names)
    self._members = [str(n) for n in enum.value_longnames]


  def generate_declaration(self):
    return 'const char* EnumToString(%s\nvalue);\n;' % (self.name)


  def generate_definition(self):
    result = '''\
const char* EnumToString(
  %s value) {
    switch (value) {\n''' % (self.name)

    for full_name in self._members:
      short_name = full_name.replace('%s_' % self.name, '')
      result += '''\
    case %s:
        return "%s";\n''' % (full_name, short_name)

    result += '''
    }
    return "<unknown enum value>";
}\n\n'''

    return result

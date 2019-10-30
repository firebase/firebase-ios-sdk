class FilePrettyPrintingInfo:
  """Describes how to generate pretty-printing code for this file."""

  def __init__(self, parsed_file, base_filename):
    self.name = base_filename
    self.messages = [MessagePrettyPrintingInfo(m) for m in parsed_file.messages]
    self.enums = [EnumPrettyPrintingInfo(e) for e in parsed_file.enums]


class MessagePrettyPrintingInfo:
  """Describes how to generate pretty-printing code for this message.
  """

  def __init__(self, message):
    self.short_classname = message.name.parts[-1]
    self.full_classname = str(message.name)
    self.fields = [self._create_field(f, message) for f in message.fields]
    # Make sure fields are printed ordered by tag, for consistency with official
    # proto libraries.
    self.fields.sort(key=lambda f: f.tag)

  def _create_field(self, field, message):
    if isinstance(field, nanopb.OneOf):
      return OneOfPrettyPrintingInfo(field, message)
    else:
      return FieldPrettyPrintingInfo(field, message)


class FieldPrettyPrintingInfo:
  """Describes how to generate pretty-printing code for this field.
  """

  def __init__(self, field, message):
    self.name = field.name
    self.full_classname = str(message.name)

    self.tag = field.tag

    self.is_optional = field.rules == 'OPTIONAL' and field.allocation == 'STATIC'
    self.is_repeated = field.rules == 'REPEATED'
    self.is_oneof = False

    self.is_primitive = field.pbtype != 'MESSAGE'
    self.is_enum = field.pbtype in ['ENUM', 'UENUM']


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
    a message, it will delegate printing to its `ToString()` member function.
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

    if parent_oneof and not parent_oneof.is_anonymous:
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


class OneOfPrettyPrintingInfo(FieldPrettyPrintingInfo):
  """Describes how to generate pretty-printing code for this oneof field.

  Note that all members of the oneof are nested (in `fields` property).
  """

  def __init__(self, field, message):
    FieldPrettyPrintingInfo.__init__(self, field, message)

    self.is_oneof = True

    self.which = 'which_' + field.name
    self.is_anonymous = field.anonymous
    self.fields = [FieldPrettyPrintingInfo(f, message) for f in field.fields]


  def __str__(self):
    """Generates a C++ statement that can print the `oneof` field, if it is set.
    """
    which = self.which
    result = '''\
    switch (%s) {\n''' % (which)

    for f in self.fields:
      tag_name = '%s_%s_tag' % (self.full_classname, f.name)
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


class EnumPrettyPrintingInfo:
  """Describes how to generate pretty-printing code for this enum.
  """

  def __init__(self, enum):
    self.name = str(enum.names)
    self.members = [str(n) for n in enum.value_longnames]


  def generate_declaration(self):
    return 'const char* EnumToString(%s\nvalue);\n;' % (self.name)


  def generate_definition(self):
    result = '''\
const char* EnumToString(
  %s value) {
    switch (value) {\n''' % (self.name)

    for full_name in self.members:
      short_name = full_name.replace('%s_' % self.name, '')
      result += '''\
    case %s:
        return "%s";\n''' % (full_name, short_name)

    result += '''
    }
    return "<unknown enum value>";
}\n\n'''

    return result

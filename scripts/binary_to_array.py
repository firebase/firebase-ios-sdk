#!/usr/bin/env python2

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
#

"""Utility to convert binary data into a C/C++ array.

Usage: %s --input=input_file.bin [--output_source=output_source.cc]
          [--output_header=output_header.h] [--cpp_namespace=namespace]
          [--header_guard=HEADER_GUARD_TEXT] [--array=array_c_identifier]
          [--array_size=array_size_c_identifier] [--filename=override_filename]
          [--filename_identifier=filename_c_identifier]

By default, the output source file will be named the same as the input file,
but with .cc as the extension; the output header file will be named the
same as the input file but with .h as the extension.

By default, the data will be in an array named $NAME_data and the size will
be in a constant named $NAME_length, and the filename will be stored in
$NAME_filename. In all these cases, $NAME is the input filename (sans path and
extension) with runs of non-alphanumeric characters changed to underscores. The
header guard will be generated from the output header filename in a similar way.

By default, the data will be placed in the root namespace. If the data is placed
in the root namespace, it will be declared as a C array (using extern "C" if
compiled in C++ mode).

The actual size of $NAME_data is $NAME_length + 1, where it contains an extra
0x00 at the end. When data is actually text, $NAME_data can be used as a valid C
string directly.
"""

from os import path
from re import sub
import argparse
import logging
import os

arg_parser = argparse.ArgumentParser()

arg_parser.add_argument("input",
                        help="Input file containing binary data to embed.")
arg_parser.add_argument("--output_source",
                        help="Output source file, defining the array data."
                             "Must be a short file name; use logical_directory "
                             "and/or physical_directory to configure the "
                             "folder.")
arg_parser.add_argument("--output_header",
                        help="Output header file, declaring the array data."
                             "Must be a short file name; use logical_directory "
                             "and/or physical_directory to configure the "
                             "folder.")
arg_parser.add_argument("--logical_directory",
                        help="The relative path to where the generated files "
                             "will be located, used to generate header guards "
                             "and includes. By default, the current folder.")
arg_parser.add_argument("--physical_directory",
                        help="The absolute path to where the generated files "
                             "will be located. By default, equal to "
                             "logical_directory.")
arg_parser.add_argument("--array", help="Identifier for the array.")
arg_parser.add_argument("--array_size", help="Identifier for the array size.")
arg_parser.add_argument("--filename", help="Override file name in code.")
arg_parser.add_argument("--filename_identifier",
                        help="Where to put the filename.")
arg_parser.add_argument("--header_guard",
                        help="Header guard to #define in the output header.")
arg_parser.add_argument("--cpp_namespace",
                        help="C++ namespace to use. "
                             "If blank, will generate a C array.")

# How many hex bytes to display in a line. Each "0x00, " takes 6 characters, so
# a width of 12 lets us fit within 80 characters.
WIDTH = 12


def header(header_guard, namespaces, array_name, array_size_name, fileid):
  """Return a C/C++ header for the given array.

  Args:
    header_guard: Name of the HEADER_GUARD to define.
    namespaces: List of namespaces, outer to inner.
    array_name: Name of the array.
    array_size_name: Name of the array size constant.
    fileid: Name of the identifier containing the file name.

  Returns:
    A list of strings containing the C/C++ header file, line-by-line.
  """

  data = []
  data.extend([
      "// Copyright 2019 Google Inc. All Rights Reserved.",
      "",
      "#ifndef %s" % header_guard,
      "#define %s" % header_guard,
      "",
      "#include <cstdlib>",
      ""
  ])
  if namespaces:
    data.extend([
        "namespace %s {" % ns for ns in namespaces
    ])
  else:
    data.extend([
        "#if defined(__cplusplus)",
        "extern \"C\" {",
        "#endif  // defined(__cplusplus)"])

  data.extend([
      "",
      "extern const size_t %s;" % array_size_name,
      "extern const unsigned char %s[];" % array_name,
      "extern const char %s[];" % fileid,
  ])

  data.extend([
      ""
  ])
  if namespaces:
    data.extend([
        "}  // namespace %s" % ns for ns in reversed(namespaces)
    ])
  else:
    data.extend([
        "#if defined(__cplusplus)",
        "}  // extern \"C\"",
        "#endif  // defined(__cplusplus)"
    ])
  data.extend([
      "",
      "#endif  // %s" % header_guard,
      ""
  ])
  return data


def source(namespaces, array_name, array_size_name, fileid, filename,
           input_bytes, include_name):
  """Return a C/C++ source file for the given array.

  Args:
    namespaces: List of namespaces, outer to inner.
    array_name: Name of the array.
    array_size_name: Name of the array size constant.
    fileid: Name of the identifier containing the filename.
    filename: The original data filename itself.
    input_bytes: Binary data to put into the array.
    include_name: Name of the corresponding header file to include.

  Returns:
    A string containing the C/C++ source file.
  """
  data = []
  data.extend([
      "// Copyright 2019 Google Inc. All Rights Reserved.",
      "",
      "#include <cstdlib>",
      "",
      "#include \"%s\"" % include_name,
      ""
  ])
  if namespaces:
    data.extend([
        "namespace %s {" % ns for ns in namespaces
    ])
  else:
    data.extend([
        "#if defined(__cplusplus)",
        "extern \"C\" {",
        "#endif  // defined(__cplusplus)"])

  data.extend([
      "",
      "extern const size_t %s;" % array_size_name,
      "extern const char %s[];" % fileid,
      "extern const unsigned char %s[];" % array_name, "",
      "const unsigned char %s[] = {" % array_name
  ])
  length = len(input_bytes)
  line = ""
  for idx in range(0, length):
    if idx % WIDTH == 0:
      line += "    "
    else:
      line += " "
    line += "0x%02x," % input_bytes[idx]
    if idx % WIDTH == WIDTH - 1:
      data.append(line)
      line = ""
  data.append(line)
  data.append("    0x00  // Extra \\0 to make it a C string")

  data.extend([
      "};",
      "",
      "const size_t %s =" % array_size_name,
      "    sizeof(%s) - 1;" % array_name,
      "",
      "const char %s[] = \"%s\";" % (fileid, filename),
      "",
  ])

  if namespaces:
    data.extend([
        "}  // namespace %s" % ns for ns in namespaces
    ][::-1])  # close namespaces in reverse order
  else:
    data.extend([
        "#if defined(__cplusplus)",
        "}  // extern \"C\"",
        "#endif  // defined(__cplusplus)"
    ])
  data.extend([
      ""
  ])
  return data


def main():
  """Read an binary input file and output to a C/C++ source file as an array.
  """

  args = arg_parser.parse_args()

  input_file = args.input
  input_file_base = os.path.splitext(args.input)[0]

  output_source = args.output_source
  if not output_source:
    output_source = input_file_base + ".cc"
    logging.debug("Using default --output_source='%s'", output_source)

  output_header = args.output_header
  if not output_header:
    output_header = input_file_base + ".h"
    logging.debug("Using default --output_header='%s'", output_header)

  if path.dirname(output_source) or path.dirname(output_header):
    raise ValueError("output_source and output_header should be short file "
                   + "names. Use logical_directory and/or physical_directory "
                   + "to specify the folder.")

  logical_directory = args.logical_directory
  if not logical_directory:
    logical_directory = ''
    logging.debug("Using current folder for output")

  physical_directory = args.physical_directory
  if not physical_directory:
    physical_directory = logical_directory
    logging.debug("Using the same physical directory as the logical directory")

  identifier_base = sub("[^0-9a-zA-Z]+", "_", path.basename(input_file_base))
  array_name = args.array
  if not array_name:
    array_name = identifier_base + "_data"
    logging.debug("Using default --array='%s'", array_name)

  array_size_name = args.array_size
  if not array_size_name:
    array_size_name = identifier_base + "_size"
    logging.debug("Using default --array_size='%s'", array_size_name)

  fileid = args.filename_identifier
  if not fileid:
    fileid = identifier_base + "_filename"
    logging.debug("Using default --filename_identifier='%s'", fileid)

  filename = args.filename
  if filename is None:  # but not if it's the empty string
    filename = path.basename(input_file)
    logging.debug("Using default --filename='%s'", filename)

  header_guard = args.header_guard
  if not header_guard:
    relative_header_name = path.join(logical_directory, output_header)
    header_guard = sub("[^0-9a-zA-Z]+", "_", relative_header_name).upper() + '_'
    # Avoid double underscores to stay compliant with the Standard.
    header_guard = sub("[_]+", "_", header_guard)
    logging.debug("Using default --header_guard='%s'", header_guard)

  namespace = args.cpp_namespace
  namespaces = namespace.split("::") if namespace else []

  with open(input_file, "rb") as infile:
    input_bytes = bytearray(infile.read())
    logging.debug("Read %d bytes from %s", len(input_bytes), input_file)

  header_text = "\n".join(header(header_guard, namespaces, array_name,
                                 array_size_name, fileid))
  include_name = path.join(logical_directory, output_header)
  source_text = "\n".join(source(namespaces, array_name, array_size_name,
                                 fileid, filename, input_bytes, include_name))

  output_header_path = path.join(physical_directory, output_header)
  with open(output_header_path, "w") as hdr:
    hdr.write(header_text)
    logging.debug("Wrote header file %s", output_header)

  output_source_path = path.join(physical_directory, output_source)
  with open(output_source_path, "w") as src:
    src.write(source_text)
    logging.debug("Wrote source file %s", output_source)


if __name__ == "__main__":
  main()

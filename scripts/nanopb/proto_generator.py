#! /usr/bin/env python

# Copyright 2022 Google LLC
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

Example usage:

python Crashlytics/ProtoSupport/build_protos.py \
  --nanopb \
  --protos_dir=Crashlytics/Classes/Protos/ \
  --pythonpath=~/Downloads/nanopb-0.3.9.2-macosx-x86/generator/ \
  --output_dir=Crashlytics/Protogen/
"""

from __future__ import print_function
from inspect import signature

import sys

import argparse
import os
import os.path
import re
import subprocess


OBJC_GENERATOR = 'nanopb_objc_generator.py'

COPYRIGHT_NOTICE = '''
/*
 * Copyright 2022 Google LLC
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
        '--nanopb', action='store_true',
        help='Generates nanopb messages.')
    parser.add_argument(
        '--objc', action='store_true',
        help='Generates Objective-C messages.')
    parser.add_argument(
        '--protos_dir',
        help='Source directory containing .proto files.')
    parser.add_argument(
        '--output_dir', '-d',
        help='Directory to write files; subdirectories will be created.')
    parser.add_argument(
        '--protoc', default='protoc',
        help='Location of the protoc executable')
    parser.add_argument(
        '--pythonpath',
        help='Location of the protoc python library.')
    parser.add_argument(
        '--include', '-I', action='append', default=[],
        help='Adds INCLUDE to the proto path.')
    parser.add_argument(
        '--include_prefix', '-p', action='append', default=[],
        help='Adds include_prefix to the <product>.nanopb.h include in'
             ' .nanopb.c')

    args = parser.parse_args()
    if args.nanopb is None and args.objc is None:
        parser.print_help()
        sys.exit(1)

    if args.protos_dir is None:
        root_dir = os.path.abspath(os.path.dirname(__file__))
        args.protos_dir = os.path.join(root_dir, 'protos')

    if args.output_dir is None:
        root_dir = os.path.abspath(os.path.dirname(__file__))
        args.output_dir = os.path.join(
            root_dir, 'protogen-please-supply-an-outputdir')

    all_proto_files = collect_files(args.protos_dir, '.proto')
    if args.nanopb:
        NanopbGenerator(args, all_proto_files).run()

    if args.objc:
        print('Generating objc code is unsupported because it depends on the'
              'main protobuf Podspec that adds a lot of size to SDKs.')


class NanopbGenerator(object):
    """Builds and runs the nanopb plugin to protoc."""

    def __init__(self, args, proto_files):
        self.args = args
        self.proto_files = proto_files

    def run(self):
        """Performs the action of the generator."""

        nanopb_out = os.path.join(self.args.output_dir, 'nanopb')
        mkdir(nanopb_out)

        self.__run_generator(nanopb_out)

        sources = collect_files(nanopb_out, '.nanopb.h', '.nanopb.c')
        post_process_files(
            sources,
            add_copyright,
            nanopb_remove_extern_c,
            nanopb_rename_delete,
            nanopb_use_module_import,
            make_use_absolute_import(nanopb_out, self.args)
        )

    def __run_generator(self, out_dir):
        """Invokes protoc using the nanopb plugin."""
        cmd = protoc_command(self.args)

        gen = os.path.join(os.path.dirname(__file__), OBJC_GENERATOR)
        cmd.append('--plugin=protoc-gen-nanopb=%s' % gen)

        nanopb_flags = [
            '--extension=.nanopb',
            '--source-extension=.c',
            '--no-timestamp'
        ]
        nanopb_flags.extend(['-I%s' % path for path in self.args.include])
        cmd.append('--nanopb_out=%s:%s' % (' '.join(nanopb_flags), out_dir))

        cmd.extend(self.proto_files)
        run_protoc(self.args, cmd)


def protoc_command(args):
    """Composes the initial protoc command-line including its include path."""
    cmd = [args.protoc]
    if args.include is not None:
        cmd.extend(['-I=%s' % path for path in args.include])
    return cmd


def run_protoc(args, cmd):
    """Actually runs the given protoc command.

    Args:
      args: The command-line args (including pythonpath)
      cmd: The command to run expressed as a list of strings
    """
    kwargs = {}
    if args.pythonpath:
        env = os.environ.copy()
        old_path = env.get('PYTHONPATH')
        env['PYTHONPATH'] = os.path.expanduser(args.pythonpath)
        if old_path is not None:
            env['PYTHONPATH'] += os.pathsep + old_path
        kwargs['env'] = env

    try:
        outputString = subprocess.check_output(
            cmd, stderr=subprocess.STDOUT, **kwargs)
        print(outputString.decode("utf-8"))
    except subprocess.CalledProcessError as error:
        print('command failed: ', ' '.join(cmd), '\nerror: ', error.output)


def post_process_files(filenames, *processors):
    for filename in filenames:
        lines = []
        with open(filename, 'r') as fd:
            lines = fd.readlines()

        for processor in processors:
            sig = signature(processor)
            if len(sig.parameters) == 1:
                lines = processor(lines)
            else:
                lines = processor(lines, filename)

        write_file(filename, lines)


def write_file(filename, lines):
    mkdir(os.path.dirname(filename))
    with open(filename, 'w') as fd:
        fd.write(''.join(lines))


def add_copyright(lines):
    """Adds a copyright notice to the lines."""
    if COPYRIGHT_NOTICE in lines:
        return lines
    result = [COPYRIGHT_NOTICE, '\n']
    result.extend(lines)
    return result


def nanopb_remove_extern_c(lines):
    """Removes extern "C" directives from nanopb code.

    Args:
      lines: A nanobp-generated source file, split into lines.
    Returns:
      A list of strings, similar to the input but modified to remove extern "C".
    """
    result = []
    state = 'initial'
    for line in lines:
        if state == 'initial':
            if '#ifdef __cplusplus' in line:
                state = 'in-ifdef'
                continue

            result.append(line)

        elif state == 'in-ifdef':
            if '#endif' in line:
                state = 'initial'

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


# Don't let Copybara alter these lines.
def nanopb_use_module_import(lines):
    """Changes #include <pb.h> to include <nanopb/pb.h>"""
    return [line.replace('#include <pb.h>',
            '{}include <nanopb/pb.h>'.format("#"))
            for line in lines]


def make_use_absolute_import(nanopb_out, args):
    import_file = collect_files(nanopb_out, '.nanopb.h')[0]

    def nanopb_use_absolute_import(lines, filename):
        """Makes repo-relative imports

           #include "crashlytics.nanopb.h" =>
           #include "Crashlytics/Protogen/nanopb/crashlytics.nanopb.h"

           This only applies to .nanopb.c files because it causes errors if
           .nanopb.h files import other .nanopb.h files with full relative
           paths.
        """
        if ".h" in filename:
            return lines
        include_prefix = args.include_prefix[0]
        header = os.path.basename(import_file)
        return [line.replace('#include "{0}"'.format(header),
                '#include "{0}{1}"'.format(include_prefix, header))
                for line in lines]

    return nanopb_use_absolute_import


def strip_trailing_whitespace(lines):
    """Removes trailing whitespace from the given lines."""
    return [line.rstrip() + '\n' for line in lines]


def objc_flatten_imports(lines):
    """Flattens the import statements for compatibility with CocoaPods."""

    long_import = re.compile(r'#import ".*/')
    return [long_import.sub('#import "', line) for line in lines]


def objc_strip_extension_registry(lines):
    """Removes extensionRegistry methods from the classes."""
    skip = False
    result = []
    for line in lines:
        if '+ (GPBExtensionRegistry*)extensionRegistry {' in line:
            skip = True
        if not skip:
            result.append(line)
        elif line == '}\n':
            skip = False

    return result


def collect_files(root_dir, *extensions):
    """Finds files with the given extensions in the root_dir.

    Args:
      root_dir: The directory from which to start traversing.
      *extensions: Filename extensions (including the leading dot) to find.

    Returns:
      A list of filenames, all starting with root_dir, that have one of the
      given extensions.
    """
    result = []
    for root, _, files in os.walk(root_dir):
        for basename in files:
            for ext in extensions:
                if basename.endswith(ext):
                    filename = os.path.join(root, basename)
                    result.append(filename)
    return result


def mkdir(dirname):
    if not os.path.isdir(dirname):
        os.makedirs(dirname)


if __name__ == '__main__':
    main()

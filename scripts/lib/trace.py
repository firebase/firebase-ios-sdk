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

import logging
import os
import pprint
import subprocess
import threading

_commands = logging.getLogger('commands')
_columns = None
_output_lock = threading.Lock()


def _find_terminal_columns():
  try:
    with open(os.devnull, 'wb') as dev_null:
      result = subprocess.check_output(['tput', 'cols'], stderr=dev_null)
      return int(result.rstrip())
  except subprocess.CalledProcessError:
    return 80


def pp(message):
  with _output_lock:
    pprint.pprint(message)


def command(command_args):
  """Traces that a command has run.

  Args:
    command_args: A list of the command and its arguments.
  """
  if _commands.isEnabledFor(logging.DEBUG):
    global _columns
    if _columns is None:
      _columns = _find_terminal_columns()

    text = ' '.join(command_args)

    # When just passing --trace, shorten output to the width of the current
    # window. When running extra verbose don't shorten.
    if not logging.root.isEnabledFor(logging.INFO):
      if len(text) >= _columns:
        text = text[0:_columns - 5] + ' ...'

    with _output_lock:
      _commands.debug('%s', text)


def add_arguments(parser):
  """Adds standard arguments to the given ArgumentParser."""
  parser.add_argument('--trace', action='store_true',
                      help='show commands')
  parser.add_argument('--verbose', '-v', action='count', default=0,
                      help='run verbosely')


def trace_commands():
  """Enables tracing of command execution."""
  with _output_lock:
    _commands.setLevel(logging.DEBUG)


def setup(args):
  """Prepares for tracing/verbosity based on the given parsed arguments."""
  level = logging.WARN

  if args.trace:
    trace_commands()

  if args.verbose >= 2:
    level = logging.DEBUG
  elif args.verbose >= 1:
    level = logging.INFO

  logging.basicConfig(format='%(message)s', level=level)


def parse_args(parser):
  """Shortcut that adds argumets, parses, and runs setup.

  Returns:
    The args result from parser.parse_args().
  """
  add_arguments(parser)
  args = parser.parse_args()
  setup(args)
  return args

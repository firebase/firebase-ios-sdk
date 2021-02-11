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

import fnmatch
import logging
import os
import re
import textwrap

from lib import command_trace


# Paths under which all files should be ignored
IGNORE = frozenset([
    'Firestore/Protos/nanopb',
    'Firestore/Protos/cpp',
    'Firestore/Protos/objc',
    'Firestore/third_party/abseil-cpp',
])

FIRESTORE_CORE = ['Firestore/core']
FIRESTORE_OBJC = ['Firestore/Source', 'Firestore/Example/Tests']
FIRESTORE_SWIFT = ['Firestore/Swift']

FIRESTORE_TESTS = ['Firestore/core/test', 'Firestore/Example/Tests']

CC_DIRS = FIRESTORE_CORE
CC_EXTENSIONS = ['.h', '.cc']

OBJC_DIRS = FIRESTORE_CORE + FIRESTORE_OBJC
OBJC_EXTENSIONS = ['.h', '.m', '.mm']

PYTHON_DIRS = ['scripts']
PYTHON_EXTENSIONS = ['.py']

SOURCE_EXTENSIONS = [
    '.c',
    '.cc',
    '.cmake',
    '.h',
    '.js',
    '.m',
    '.mm',
    '.py',
    '.rb',
    '.sh',
    '.swift'
]

_DEFINITE_EXTENSIONS = {
    '.cc': 'cc',
    '.m': 'objc',
    '.mm': 'objc',
    '.py': 'py',
}


_classify_logger = logging.getLogger('lint.classify')


class LanguageBreakdown:
  """Files broken down by source language."""

  def __init__(self):
    self.cc = []
    self.objc = []
    self.py = []
    self.all = []

    self.kinds = {
        'cc': self.cc,
        'objc': self.objc,
        'py': self.py,
    }

  def classify(self, kind, reason, filename):
    _classify_logger.debug('classify %s: %s (%s)' % (kind, filename, reason))
    self.kinds[kind].append(filename)
    self.all.append(filename)

  @staticmethod
  def ignore(filename):
    _classify_logger.debug('classify ignored: %s' % filename)


def categorize_files(files):
  """Breaks down the given list of files by language.

  Args:
    files: a list of files

  Returns:
    A LanguageBreakdown instance containing all the files that match a
    recognized source language.
  """
  result = LanguageBreakdown()

  for filename in files:
    if _in_directories(filename, IGNORE):
      continue

    ext = os.path.splitext(filename)[1]
    definite = _DEFINITE_EXTENSIONS.get(ext)
    if definite:
      result.classify(definite, 'extension', filename)
      continue

    if ext == '.h':
      if _in_directories(filename, CC_DIRS):
        # If a header exists in the C++ core, ignore related files. Some classes
        # may transiently have an implementation in a .mm file, but hold the
        # header to the higher standard: the implementation should eventually
        # be in a .cc, otherwise the file doesn't belong in the core.
        result.classify('cc', 'directory', filename)
        continue

      related_ext = _related_file_ext(filename)
      if related_ext == '.cc':
        result.classify('cc', 'related file', filename)
        continue

      if related_ext in ('.m', '.mm'):
        result.classify('objc', 'related file', filename)
        continue

      if _in_directories(filename, OBJC_DIRS):
        result.classify('objc', 'directory', filename)
        continue

      raise NotImplementedError(textwrap.dedent(
          """
          Don't know how to handle the header %s.

          If C++ add a parent directory to CC_DIRS in lib/source.py.

          If Objective-C add to OBJC_DIRS or consider changing the default here
          and removing this exception.""" % filename))

    result.ignore(filename)

  return result


def shard(group, num_shards):
  """Breaks the group apart into num_shards shards.

  Args:
    group: a breakdown, perhaps returned from categorize_files.
    num_shards: The number of shards into which to break down the group.

  Returns:
    A list of shards.
  """
  shards = []
  for i in range(num_shards):
    shards.append(LanguageBreakdown())

  pos = 0
  for kind, files in group.kinds.items():
    for filename in files:
      shards[pos].kinds[kind].append(filename)
      pos = (pos + 1) % num_shards

  return shards


_PLUS = re.compile(r'\+.*')


def _related_file_ext(header):
  """Returns the dominant extension among related files.

  A file is related if it starts with the same prefix. Prefix is the basename
  without extension, and stripping off any + category names that are common in
  Objective-C.

  For example: executor.h has related files executor_std.cc and
  executor_libdispatch.mm.

  If there are multiple related files, the implementation chooses one based
  on which language is most restrictive. That is, if a header serves both C++
  and Objective-C++ implementations, lint the header as C++ to prevent issues
  that might arise in that mode.

  Returns:
    The file extension (e.g. '.cc')
  """
  parent = os.path.dirname(header)
  basename = os.path.basename(header)

  root = os.path.splitext(basename)[0]
  root = _PLUS.sub('', root)
  root = os.path.join(parent, root)

  files = _related_files(root)
  exts = {os.path.splitext(f)[1] for f in files}

  for ext in ('.cc', '.m', '.mm'):
    if ext in exts:
      return ext
  return None


def _related_files(root):
  """Returns a list of files related to the given root.
  """
  parent = os.path.dirname(root)
  if not parent:
    # dirname returns empty for filenames that are already a basename.
    parent = '.'

  pattern = os.path.basename(root) + '*'
  return fnmatch.filter(_list_files(parent), pattern)


def _list_files(parent):
  """Lists files contained directly in the parent directory."""
  result = _list_files.cache.get(parent)
  if result is None:
    command_trace.log(['ls', parent])
    result = os.listdir(parent)
    _list_files.cache[parent] = result
  return result


_list_files.cache = {}


def _in_directories(filename, dirs):
  """Tests whether `filename` is anywhere in any of the given dirs."""
  for dirname in dirs:
    if (filename.startswith(dirname)
        and (len(filename) == len(dirname) or filename[len(dirname)] == '/')):
      return True
  return False

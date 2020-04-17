# Copyright 2020 Google LLC
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

import ast
import json

"""
LLDB type summary providers for common Firestore types.

This is primarily useful for debugging Firestore internals. It will add useful
summaries and consolidate common types in a way that makes them easier to
observe in the debugger.

Use this by adding the following to your ~/.lldbinit file:

    command script import ~/path/to/firebase-ios-sdk/scripts/lldb/firestore.py

Most of this implementation is based on "Variable Formatting" in the LLDB online
manual: https://lldb.llvm.org/use/variable.html. There are two major features
we're making use of:

  * Summary Providers: these are classes or functions that take an object and
    produce a (typically one line) summary of the type

  * Synthetic Children Providers: these are classes that provide an alternative
    view of the data. The children that are synthesized here show up in the
    graphical debugger.
"""


# model

def DocumentKey_SummaryProvider(value, params):
  """Summarizes DocumentKey as if path_->segments_ were inline and a single
  string."""
  return deref_shared(value.GetChildMemberWithName('path_')).GetSummary()


def ResourcePath_SummaryProvider(value, params):
  """Summarizes ResourcePath as if segments_ is a single string."""

  segments = value.GetChildMemberWithName('segments_')
  count = segments.GetNumChildren()

  segment_text = []
  for i in range(0, count):
    child = segments.GetChildAtIndex(i)
    segment_text.append(get_string(child))

  text = format_string('/'.join(segment_text))
  return text


# api

def DocumentReference_SummaryProvider(value, params):
  return value.GetChildMemberWithName('key_').GetSummary()


def DocumentSnapshot_SummaryProvider(value, params):
  return value.GetChildMemberWithName('internal_key_').GetSummary()


# Objective-C

def FIRDocumentReference_SummaryProvider(value, params):
  return value.GetChildMemberWithName('_documentReference').GetSummary()


def FIRDocumentSnapshot_SummaryProvider(value, params):
  return value.GetChildMemberWithName('_snapshot').GetSummary()


def get_string(value):
  """Returns a Python string from the underlying LLDB SBValue."""
  # TODO(wilhuff): This is gross hack. Actually use the SBData API to get this.
  summary = value.GetSummary()
  return ast.literal_eval(summary)


def format_string(string):
  """Formats a Python string as a C++ string literal."""
  # JSON and C escapes work the ~same.
  return json.dumps(string)


def deref_shared(value):
  """Dereference a shared_ptr."""
  return value.GetChildMemberWithName('__ptr_').Dereference()


def __lldb_init_module(debugger, params):
  def run(command):
    debugger.HandleCommand(command)

  def add_summary(provider, typename, *args):
    args = ' '.join(args)
    run('type summary add -w firestore -F {0} {1} {2}'.format(
      qname(provider), args, typename))

  api = 'firebase::firestore::api::'
  add_summary(DocumentReference_SummaryProvider, api + 'DocumentReference')
  add_summary(DocumentSnapshot_SummaryProvider, api + 'DocumentSnapshot', '-e')

  model = 'firebase::firestore::model::'
  add_summary(DocumentKey_SummaryProvider, model + 'DocumentKey')
  add_summary(ResourcePath_SummaryProvider, model + 'ResourcePath')

  add_summary(FIRDocumentReference_SummaryProvider, 'FIRDocumentReference')

  add_summary(FIRDocumentSnapshot_SummaryProvider, 'FIRDocumentSnapshot', '-e')

  run('type category enable firestore')


def qname(fn):
  """Returns the module-qualified name of the given class or function."""
  return '{0}.{1}'.format(__name__, fn.__name__)

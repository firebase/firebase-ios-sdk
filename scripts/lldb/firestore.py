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


class ForwardingSynthProvider(object):
  """A synthetic child provider that forwards all methods to another provider.

  Override the `delegate` method to customize the target to which this forwards.
  """

  def __init__(self, value, params):
    self.value = value

  def delegate(self):
    return self.value

  def has_children(self):
    return self.delegate().MightHaveChildren()

  def num_children(self):
    return self.delegate().GetNumChildren()

  def get_child_index(self, name):
    return self.delegate().GetIndexOfChildWithName(name)

  def get_child_at_index(self, index):
    return self.delegate().GetChildAtIndex(index)

  def update(self):
    # No additional state so nothing needs updating when the value changes.
    pass


# Abseil

class AbseilOptional_SynthProvider(object):
  """A synthetic child provider that hides the internals of absl::optional.
  """

  def __init__(self, value, params):
    self.value = value
    self.engaged = None
    self.data = None

  def update(self):
    # Unwrap all the internal optional_data and similar types
    value = self.value
    while True:
      if value.GetNumChildren() <= 0:
        break

      child = value.GetChildAtIndex(0)
      if not child.IsValid():
        break

      if 'optional_internal' not in child.GetType().GetName():
        break

      value = child

    # value should now point to the innermost absl::optional container type.
    self.engaged = value.GetChildMemberWithName('engaged_')

    if self.has_children():
      self.data = value.GetChildMemberWithName('data_')

    else:
      self.data = None

  def has_children(self):
    return self.engaged.GetValueAsUnsigned(0) != 0

  def num_children(self):
    return 2 if self.has_children() else 1

  def get_child_index(self, name):
    if name == 'engaged_':
      return 0
    if name == 'data_':
      return 1
    return -1

  def get_child_at_index(self, index):
    if index == 0:
      return self.engaged
    if index == 1:
      return self.data


def AbseilOptional_SummaryProvider(value, params):
  # Operates on the synthetic children above, calling has_children.
  return 'engaged={0}'.format(format_bool(value.MightHaveChildren()))


# model

class DatabaseId_SynthProvider(ForwardingSynthProvider):
  """Makes DatabaseId behave as if `*rep_` were inline, hiding its
  `shared_ptr<Rep>` implementation details.
  """
  def delegate(self):
    return deref_shared(self.value.GetChildMemberWithName('rep_'))


def DatabaseId_SummaryProvider(value, params):
  # Operates on the result of the SynthProvider; value is *rep_.
  parts = [
      get_string(value.GetChildMemberWithName('project_id')),
      get_string(value.GetChildMemberWithName('database_id'))
  ]
  return format_string('/'.join(parts))


def DocumentKey_SummaryProvider(value, params):
  """Summarizes DocumentKey as if path_->segments_ were inline and a single,
  slash-delimited string like `"users/foo"`.
  """
  return deref_shared(value.GetChildMemberWithName('path_')).GetSummary()


def ResourcePath_SummaryProvider(value, params):
  """Summarizes ResourcePath as if segments_ were a single string,
  slash-delimited string like `"users/foo"`.
  """
  segments = value.GetChildMemberWithName('segments_')
  segment_text = [get_string(child) for child in segments]
  return format_string('/'.join(segment_text))


# api

def DocumentReference_SummaryProvider(value, params):
  """Summarizes DocumentReference as a single slash-delimited string like
  `"users/foo"`.
  """
  return value.GetChildMemberWithName('key_').GetSummary()


def DocumentSnapshot_SummaryProvider(value, params):
  """Summarizes DocumentSnapshot as a single slash-delimited string like
  `"users/foo"` that names the path of the document in the snapshot.
  """
  return value.GetChildMemberWithName('internal_key_').GetSummary()


# Objective-C

def FIRDocumentReference_SummaryProvider(value, params):
  return value.GetChildMemberWithName('_documentReference').GetSummary()


def FIRDocumentSnapshot_SummaryProvider(value, params):
  return value.GetChildMemberWithName('_snapshot').GetSummary()


def get_string(value):
  """Returns a Python string from the underlying LLDB SBValue."""
  # TODO(wilhuff): Actually use the SBData API to get this.
  # Get the summary as a C literal and parse it (for now). Using the SBData
  # API would allow this to directly read the string contents.
  summary = value.GetSummary()
  return ast.literal_eval(summary)


def format_string(string):
  """Formats a Python string as a C++ string literal."""
  # JSON and C escapes work the ~same.
  return json.dumps(string)


def format_bool(value):
  """Formats a Python value as a C++ bool literal."""
  return 'true' if value else 'false'


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

  def add_synthetic(provider, typename, *args):
    args = ' '.join(args)
    run('type synthetic add -l {0} -w firestore {1} {2}'.format(
        qname(provider), args, typename))

  optional_matcher = '-x absl::[^:]*::optional<.*>'
  add_summary(AbseilOptional_SummaryProvider, optional_matcher, '-e')
  add_synthetic(AbseilOptional_SynthProvider, optional_matcher)

  api = 'firebase::firestore::api::'
  add_summary(DocumentReference_SummaryProvider, api + 'DocumentReference')
  add_summary(DocumentSnapshot_SummaryProvider, api + 'DocumentSnapshot', '-e')

  model = 'firebase::firestore::model::'
  add_summary(DocumentKey_SummaryProvider, model + 'DocumentKey')
  add_summary(ResourcePath_SummaryProvider, model + 'ResourcePath')

  add_summary(DatabaseId_SummaryProvider, model + 'DatabaseId')
  add_synthetic(DatabaseId_SynthProvider, model + 'DatabaseId')

  add_summary(FIRDocumentReference_SummaryProvider, 'FIRDocumentReference')

  add_summary(FIRDocumentSnapshot_SummaryProvider, 'FIRDocumentSnapshot', '-e')

  run('type category enable firestore')


def qname(fn):
  """Returns the module-qualified name of the given class or function."""
  return '{0}.{1}'.format(__name__, fn.__name__)

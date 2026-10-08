# Copyright 2026 Google LLC
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

"""Unit tests for swift_typegen.models."""

import unittest

from swift_typegen.models import SwiftProperty, SwiftType


class TestSwiftType(unittest.TestCase):

    def test_list_fields_are_not_shared_between_instances(self):
        a = SwiftType(name="A", namespace="", kind="struct")
        b = SwiftType(name="B", namespace="", kind="struct")
        a.properties.append(
            SwiftProperty(swift_name="x", json_name="x", swift_type="Int")
        )
        self.assertEqual(b.properties, [])


class TestSwiftProperty(unittest.TestCase):

    def test_needs_explicit_coding_key(self):
        prop_same = SwiftProperty(
            swift_name="candidateCount",
            json_name="candidateCount",
            swift_type="Int",
        )
        self.assertFalse(prop_same.needs_explicit_coding_key)

        prop_escaped_same = SwiftProperty(
            swift_name="`default`",
            json_name="default",
            swift_type="Bool",
        )
        self.assertFalse(prop_escaped_same.needs_explicit_coding_key)

        prop_diff = SwiftProperty(
            swift_name="maxOutputTokens",
            json_name="max_output_tokens",
            swift_type="Int",
        )
        self.assertTrue(prop_diff.needs_explicit_coding_key)

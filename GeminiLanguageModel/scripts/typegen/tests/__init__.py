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

"""Unit tests for the swift_typegen package.

These tests import `swift_typegen` from `scripts/`, so `scripts/` must be the
top-level directory. From the repository root:

    python -m unittest discover scripts                    # all tests
    python -m unittest discover -s scripts/tests -t scripts  # generator only

A single module, from `scripts/`:

    python -m unittest tests.test_render
"""

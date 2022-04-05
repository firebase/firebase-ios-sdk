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

import leveldb_patch
import pathlib
import unittest


class CMakeListsPatcherTest(unittest.TestCase):

  def setUp(self):
    super().setUp()
    self.snappy_source_dir = pathlib.Path("a/b/snappy_source_dir")
    self.snappy_binary_dir = pathlib.Path("a/b/snappy_binary_dir")

  def test_snappy_detect_line_is_commented_and_replaced(self):
    lines = (
      """check_library_exists(snappy snappy_compress "" HAVE_SNAPPY)\n""",
    )
    patcher = leveldb_patch.CMakeListsPatcher(
        lines, self.snappy_source_dir, self.snappy_binary_dir)

    patched_lines = tuple(patcher.patch())

    self.assertSequenceEqual(patched_lines, [
      """# check_library_exists(snappy snappy_compress "" HAVE_SNAPPY)\n""",
      """set(HAVE_SNAPPY ON CACHE BOOL "")\n""",
    ])

  def test_snappy_detect_line_has_indent_and_eol_preserved(self):
    lines = (
      """  check_library_exists(snappy snappy_compress "" HAVE_SNAPPY)   \n""",
    )
    patcher = leveldb_patch.CMakeListsPatcher(
        lines, self.snappy_source_dir, self.snappy_binary_dir)

    patched_lines = tuple(patcher.patch())

    self.assertSequenceEqual(patched_lines, [
      """  # check_library_exists(snappy snappy_compress "" HAVE_SNAPPY)   \n""",
      """  set(HAVE_SNAPPY ON CACHE BOOL "")   \n""",
    ])

  def test_snappy_detect_line_does_not_affect_surrounding_lines(self):
    lines = (
      "aaa",
      "bbb",
      """check_library_exists(snappy snappy_compress "" HAVE_SNAPPY)""",
      "ccc",
      "ddd",
    )
    patcher = leveldb_patch.CMakeListsPatcher(
        lines, self.snappy_source_dir, self.snappy_binary_dir)

    patched_lines = tuple(patcher.patch())

    self.assertSequenceEqual(patched_lines, [
      "aaa",
      "bbb",
      """# check_library_exists(snappy snappy_compress "" HAVE_SNAPPY)""",
      """set(HAVE_SNAPPY ON CACHE BOOL "")""",
      "ccc",
      "ddd",
    ])

  def test_snappy_include_is_amended(self):
    lines = (
      "target_include_directories(leveldb",
      "PUBLIC",
      "path1",
      "path2",
      ")",
    )
    patcher = leveldb_patch.CMakeListsPatcher(
      lines,
      snappy_source_dir=pathlib.Path("a/b"),
      snappy_binary_dir=pathlib.Path("c/d"),
    )

    patched_lines = tuple(patcher.patch())

    self.assertSequenceEqual(patched_lines, [
      "target_include_directories(leveldb",
      "PRIVATE",
      "a/b",
      "c/d",
      "PUBLIC",
      "path1",
      "path2",
      ")",
    ])

  def test_snappy_include_lines_adopt_indenting_and_eol_convention(self):
    lines = (
      "target_include_directories(leveldb\n",
      "  PUBLIC   \n",
      "      path1 \n",
      "      path2 \n",
      ")\n",
    )
    patcher = leveldb_patch.CMakeListsPatcher(
      lines,
      snappy_source_dir=pathlib.Path("a/b"),
      snappy_binary_dir=pathlib.Path("c/d"),
    )

    patched_lines = tuple(patcher.patch())

    self.assertSequenceEqual(patched_lines, [
      "target_include_directories(leveldb\n",
      "  PRIVATE   \n",
      "      a/b \n",
      "      c/d \n",
      "  PUBLIC   \n",
      "      path1 \n",
      "      path2 \n",
      ")\n",
    ])

  def test_snappy_include_line_does_not_affect_surrounding_lines(self):
    lines = (
      "aaa",
      "bbb",
      "target_include_directories(leveldb",
      "PUBLIC",
      "path1",
      "path2",
      ")",
      "ccc",
      "ddd",
    )
    patcher = leveldb_patch.CMakeListsPatcher(
      lines,
      snappy_source_dir=pathlib.Path("a/b"),
      snappy_binary_dir=pathlib.Path("c/d"),
    )

    patched_lines = tuple(patcher.patch())

    self.assertSequenceEqual(patched_lines, [
      "aaa",
      "bbb",
      "target_include_directories(leveldb",
      "PRIVATE",
      "a/b",
      "c/d",
      "PUBLIC",
      "path1",
      "path2",
      ")",
      "ccc",
      "ddd",
    ])

  def test_leveldb_snappy_link_line_is_commented_and_replaced(self):
    lines = (
      "target_link_libraries(leveldb snappy)",
    )
    patcher = leveldb_patch.CMakeListsPatcher(
      lines,
      snappy_source_dir=pathlib.Path("a/b"),
      snappy_binary_dir=pathlib.Path("c/d"),
    )

    patched_lines = tuple(patcher.patch())

    self.assertSequenceEqual(patched_lines, [
      "# target_link_libraries(leveldb snappy)",
      "target_link_libraries(leveldb c/d/libsnappy.a)",
    ])

  def test_leveldb_snappy_link_line_has_indent_and_eol_preserved(self):
    lines = (
      " target_link_libraries(leveldb snappy)   \n",
    )
    patcher = leveldb_patch.CMakeListsPatcher(
      lines,
      snappy_source_dir=pathlib.Path("a/b"),
      snappy_binary_dir=pathlib.Path("c/d"),
    )

    patched_lines = tuple(patcher.patch())

    self.assertSequenceEqual(patched_lines, [
      " # target_link_libraries(leveldb snappy)   \n",
      " target_link_libraries(leveldb c/d/libsnappy.a)   \n",
    ])

  def test_leveldb_snappy_link_line_does_not_affect_surrounding_lines(self):
    lines = (
      "aaa",
      "bbb",
      "target_link_libraries(leveldb snappy)",
      "ccc",
      "ddd",
    )
    patcher = leveldb_patch.CMakeListsPatcher(
      lines,
      snappy_source_dir=pathlib.Path("a/b"),
      snappy_binary_dir=pathlib.Path("c/d"),
    )

    patched_lines = tuple(patcher.patch())

    self.assertSequenceEqual(patched_lines, [
      "aaa",
      "bbb",
      "# target_link_libraries(leveldb snappy)",
      "target_link_libraries(leveldb c/d/libsnappy.a)",
      "ccc",
      "ddd",
    ])

  def test_all_patches_combined(self):
    lines = (
      """check_library_exists(snappy snappy_compress "" HAVE_SNAPPY)\n""",
      "target_include_directories(leveldb",
      "PUBLIC",
      "path1",
      ")",
      "target_link_libraries(leveldb snappy)",
    )

    patcher = leveldb_patch.CMakeListsPatcher(
      lines,
      snappy_source_dir=pathlib.Path("a/b"),
      snappy_binary_dir=pathlib.Path("c/d"),
    )
    patched_lines = tuple(patcher.patch())

    self.assertSequenceEqual(patched_lines, [
      """# check_library_exists(snappy snappy_compress "" HAVE_SNAPPY)\n""",
      """set(HAVE_SNAPPY ON CACHE BOOL "")\n""",
      "target_include_directories(leveldb",
      "PRIVATE",
      "a/b",
      "c/d",
      "PUBLIC",
      "path1",
      ")",
      "# target_link_libraries(leveldb snappy)",
      "target_link_libraries(leveldb c/d/libsnappy.a)",
    ])

  def test_idempotence(self):
    lines = (
      """check_library_exists(snappy snappy_compress "" HAVE_SNAPPY)\n""",
      "target_include_directories(leveldb",
      "PUBLIC",
      "path1",
      ")",
      "target_link_libraries(leveldb snappy)",
    )

    patcher1 = leveldb_patch.CMakeListsPatcher(
      lines,
      snappy_source_dir=pathlib.Path("a/b"),
      snappy_binary_dir=pathlib.Path("c/d"),
    )
    patched_lines1 = tuple(patcher1.patch())
    patcher2 = leveldb_patch.CMakeListsPatcher(
      patched_lines1,
      snappy_source_dir=pathlib.Path("a/b"),
      snappy_binary_dir=pathlib.Path("c/d"),
    )
    patched_lines2 = tuple(patcher2.patch())

    self.assertSequenceEqual(patched_lines1, patched_lines2)


if __name__ == "__main__":
  unittest.main()
